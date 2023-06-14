defmodule ExSip.Listeners.UDP do
  require Logger

  use GenStateMachine, callback_mode: [:handle_event_function, :state_enter]

  alias ExSip.Listeners.State
  alias ExSip.Handler
  alias ExSip.Message

  import ExSip.ErrorLogger

  def wait_for_bind(pid, timeout \\ :infinity) do
    GenStateMachine.call(pid, :wait_for_bind, timeout)
  end

  def stop(pid, reason \\ :normal, timeout \\ :infinity) do
    GenStateMachine.stop(pid, reason, timeout)
  end

  def start_link({handler, args}, gen_options \\ []) when is_atom(handler) do
    GenStateMachine.start_link(__MODULE__, {handler, args}, gen_options)
  end

  @impl true
  def init({handler, args}) do
    state = %State{handler: handler}
    case Handler.init(args, state) do
      {:ok, state} ->
        {:ok, :open, state}
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

  @impl true
  def handle_event(:enter, _old_state, :open, %State{} = state) do
    send(self(), {:socket, :open})
    {:keep_state, state}
  end

  @impl true
  def handle_event(:info, {:socket, :open}, :open, %State{} = state) do
    options = %{}
    case :socket.open(:inet, :dgram, :udp, options) do
      {:ok, socket} ->
        {:next_state, :bind, %{state | socket: socket}}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  @impl true
  def handle_event(:enter, _old_state, :bind, %State{} = state) do
    send(self(), {:socket, :bind})
    {:keep_state, state}
  end

  @impl true
  def handle_event(:info, {:socket, :bind}, :bind, %State{} = state) do
    :ok = :socket.bind(state.socket, %{
      family: :inet,
      #port: 5100,
      port: 5070,
      addr: :any,
    })
    {:next_state, :loop, state}
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  @impl true
  def handle_event(:enter, _old_state, :loop, %State{} = state) do
    Process.flag(:trap_exit, true)
    parent = self()
    state =
      %{
        state
        | receiver: spawn_link(fn ->
          receiver_loop(parent, state.socket)
        end)
      }
    send(self(), {:socket, :bound})
    {:keep_state, state}
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  @impl true
  def handle_event(:info, {:socket, :bound}, :loop, %State{} = state) do
    case Handler.handle_bound(state) do
      {:ok, %State{} = state} ->
        state = flush_waiting_for_bind(state)
        {:keep_state, state}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  @impl true
  def handle_event(:info, {:received_data, blob}, :loop, %State{} = state) do
    case Message.parse(blob) do
      {:ok, %Message{} = message} ->
        case do_handle_message(message, state) do
          {:ok, state} ->
            {:keep_state, state}
        end
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

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

  defp receiver_loop(parent, socket) do
    case :socket.recv(socket) do
      {:ok, blob} when is_binary(blob) ->
        send(parent, {:received_data, blob})
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

  defp do_handle_message(%Message{} = message, %State{} = state) do
    Handler.handle_message(message, state)
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end
end
