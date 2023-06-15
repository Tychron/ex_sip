defmodule ExSip.Listeners.UDP do
  require Logger

  use GenStateMachine, callback_mode: [:handle_event_function, :state_enter]

  alias ExSip.Listeners.State
  alias ExSip.Listeners.Handler

  import ExSip.ErrorLogger

  @server_key :__server__
  @socket_key :__socket__

  def reply(from, message) do
    GenStateMachine.reply(from, message)
  end

  def call(pid, message, timeout) do
    GenStateMachine.call(pid, {:__call__, message}, timeout)
  end

  def cast(pid, message) do
    GenStateMachine.cast(pid, {:__cast__, message})
  end

  def wait_for_bind(pid, timeout \\ :infinity) do
    GenStateMachine.call(pid, :wait_for_bind, timeout)
  end

  def stop(pid, reason \\ :normal, timeout \\ :infinity) do
    GenStateMachine.stop(pid, reason, timeout)
  end

  def start_link(options, gen_options \\ []) do
    options = extract_start_options!(options)
    GenStateMachine.start_link(__MODULE__, options, gen_options)
  end

  def start(options, gen_options \\ []) do
    options = extract_start_options!(options)
    GenStateMachine.start(__MODULE__, options, gen_options)
  end

  @impl true
  def init(options) do
    listener = Keyword.fetch!(options, :listener)
    {handler, args} = Keyword.fetch!(options, :handler)

    state = %State{
      addr: Keyword.fetch!(listener, :addr),
      handler: handler,
    }
    case Handler.init(:udp, args, state) do
      {:ok, state} ->
        {:ok, :open, state}

      {:stop, reason, %State{} = _state} ->
        {:stop, reason}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  @impl true
  def terminate(reason, _event_state, %State{} = state) do
    Process.flag(:trap_exit, false)
    if state.socket do
      :socket.close(state.socket)
    end
    Handler.terminate(reason, state)
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  #
  # General Exit handling
  #

  @impl true
  def handle_event(:info, {:EXIT, pid, _reason} = message, _, %State{} = state) do
    if pid == state.receiver do
      case Handler.handle_unbound(state) do
        {:noreply, state} ->
          {:next_state, :reopen, %{state | receiver: nil}}
      end
    else
      case Handler.handle_info(message, state) do
        {:noreply, state} ->
          {:keep_state, state}
      end
    end
  end

  #
  # Reopen
  #

  @impl true
  def handle_event(:enter, _old_state, :reopen, %State{} = state) do
    send(self(), {@server_key, :socket, :reopen})
    {:keep_state, state}
  end

  @impl true
  def handle_event(:info, {@server_key, :socket, :reopen}, :reopen, %State{} = state) do
    if state.socket do
      :socket.close(state.socket)
    end
    {:next_state, :open, %{state | socket: nil}}
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  #
  # Open
  #

  @impl true
  def handle_event(:enter, _old_state, :open, %State{} = state) do
    send(self(), {@server_key, :socket, :open})
    {:keep_state, state}
  end

  @impl true
  def handle_event(:info, {@server_key, :socket, :open}, :open, %State{} = state) do
    options = %{}
    case :socket.open(:inet, :dgram, :udp, options) do
      {:ok, socket} ->
        {:next_state, :bind, %{state | socket: socket}}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  #
  # Bind
  #

  @impl true
  def handle_event(:enter, _old_state, :bind, %State{} = state) do
    send(self(), {@server_key, :socket, :bind})
    {:keep_state, state}
  end

  @impl true
  def handle_event(:info, {@server_key, :socket, :bind}, :bind, %State{} = state) do
    case :socket.bind(state.socket, state.addr) do
      :ok ->
        {:next_state, :loop, state}

      {:error, :eaddrinuse} ->
        Logger.error "address in use, trying again in 5 seconds"
        if state.retries > 20 do
          {:stop, :could_not_bind, state}
        else
          Process.send_after(self(), {@server_key, :socket, :bind}, :timer.seconds(5))
          {:keep_state, %{state | retries: state.retries + 1}}
        end
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  #
  # Loop
  #

  @impl true
  def handle_event(:enter, _old_state, :loop, %State{} = state) do
    Process.flag(:trap_exit, true)
    parent = self()
    state =
      %{
        state
        | receiver: spawn_link(fn ->
            receiver_loop(parent, state.socket)
          end),
          retries: 0
      }
    send(self(), {@server_key, :socket, :bound})
    {:keep_state, state}
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  @impl true
  def handle_event(:info, {@server_key, :socket, :bound}, :loop, %State{} = state) do
    case Handler.handle_bound(state) do
      {:noreply, %State{} = state} ->
        state = flush_waiting_for_bind(state)
        {:keep_state, state}

      {:stop, reason, %State{} = state} ->
        {:stop, reason, state}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  @impl true
  def handle_event(:info, {@socket_key, :received_data, source, blob}, :loop, %State{} = state) do
    case Handler.decode_message(blob, state) do
      {:ok, message, %State{} = state} ->
        case Handler.handle_message(source, message, state) do
          {:ok, %State{} = state} ->
            {:keep_state, state}

          {:stop, reason, state} ->
            {:stop, reason, state}
        end

      {:error, _reason, state} ->
        {:keep_state, state}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  #
  # Wait for Bind
  #

  @impl true
  def handle_event({:call, from}, :wait_for_bind, :loop, %State{} = state) do
    {:keep_state, state, [{:reply, from, :ok}]}
  end

  @impl true
  def handle_event({:call, from}, :wait_for_bind, _event_state, %State{} = state) do
    state = put_in(state.waiting_for_bind, :queue.in(from, state.waiting_for_bind))
    {:keep_state, state}
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  #
  # Fallback
  #

  @impl true
  def handle_event({:call, from}, {:__call__, message}, _event_state, %State{} = state) do
    case Handler.handle_call(message, from, state) do
      {:noreply, state} ->
        {:keep_state, state}

      {:reply, reply, state} ->
        {:keep_state, state, [{:reply, from, reply}]}

      {:stop, reason, %State{} = state} ->
        {:stop, reason, state}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  @impl true
  def handle_event(:cast, {:__cast__, message}, _event_state, %State{} = state) do
    case Handler.handle_cast(message, state) do
      {:noreply, state} ->
        {:keep_state, state}

      {:stop, reason, %State{} = state} ->
        {:stop, reason, state}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  @impl true
  def handle_event(:info, message, _event_state, %State{} = state) do
    case Handler.handle_info(message, state) do
      {:noreply, state} ->
        {:keep_state, state}

      {:stop, reason, %State{} = state} ->
        {:stop, reason, state}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  defp receiver_loop(parent, socket) do
    case :socket.recvfrom(socket) do
      {:ok, {source, blob}} when is_binary(blob) ->
        send(parent, {@socket_key, :received_data, source, blob})
        receiver_loop(parent, socket)

      {:error, reason} ->
        exit({:error, reason})
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  defp flush_waiting_for_bind(%State{} = state) do
    case :queue.out(state.waiting_for_bind) do
      {:empty, _queue} ->
        state

      {{:value, from}, queue} ->
        GenStateMachine.reply(from, :ok)
        flush_waiting_for_bind(%{state | waiting_for_bind: queue})
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  defp extract_start_options!(options) do
    listener = Keyword.fetch!(options, :listener)
    {handler, args} = Keyword.fetch!(options, :handler)

    [
      listener: Enum.map(listener, fn
        {:addr, value} = res when is_map(value) ->
          res
      end),
      handler: {handler, args},
    ]
  end
end
