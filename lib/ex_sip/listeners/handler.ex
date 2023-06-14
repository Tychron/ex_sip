defmodule ExSip.Listeners.Handler do
  defmacro __using__(_opts) do
    quote do
      @behaviour ExSip.Listeners.Handler

      @doc false
      def init(args) do
        {:ok, args}
      end

      @doc false
      def terminate(_reason, _state) do
        :ok
      end

      @doc false
      def handle_unbound(state) do
        {:noreply, state}
      end

      @doc false
      def handle_bound(state) do
        {:noreply, state}
      end

      @doc false
      def handle_call(_message, _from, state) do
        {:stop, :unexpected_message, state}
      end

      @doc false
      def handle_cast(_message, state) do
        {:stop, :unexpected_message, state}
      end

      @doc false
      def handle_info(_message, state) do
        {:stop, :unexpected_message, state}
      end

      @doc false
      def handle_message(_source, _message, state) do
        {:ok, state}
      end

      defoverridable [
        init: 1,
        terminate: 2,
        handle_unbound: 1,
        handle_bound: 1,
        handle_message: 3
      ]
    end
  end

  alias ExSip.Listeners.State
  alias ExSip.Message

  @callback init(:udp | :tcp, args::any()) :: {:ok, any()}

  @callback terminate(reason::any(), args::any()) :: any()

  @callback handle_unbound(state::any()) :: {:noreply, any()}

  @callback handle_bound(state::any()) :: {:noreply, any()}

  @callback handle_call(message::any(), from::any(), state::any()) ::
    {:noreply, any()}
    | {:reply, any(), any()}
    | {:stop, reason::any(), any()}

  @callback handle_cast(message::any(), state::any()) ::
    {:noreply, any()}
    | {:stop, reason::any(), any()}

  @callback handle_info(message::any(), state::any()) ::
    {:noreply, any()}
    | {:stop, reason::any(), any()}

  @callback handle_message(source::any(), Message.t(), state::any()) ::
    {:ok, any()}
    | {:stop, reason::any(), any()}

  def init(transport, args, %State{} = state) do
    case state.handler.init(transport, args) do
      {:ok, handler_state} ->
        {:ok, %{state | handler_state: handler_state}}

      {:stop, reason} ->
        {:stop, reason, state}
    end
  end

  def terminate(reason, %State{} = state) do
    case state.handler.terminate(reason, state.handler_state) do
      {:ok, handler_state} ->
        {:ok, %{state | handler_state: handler_state}}
    end
  end

  def handle_unbound(%State{} = state) do
    case state.handler.handle_unbound(state.handler_state) do
      {:noreply, handler_state} ->
        {:noreply, %{state | handler_state: handler_state}}
    end
  end

  def handle_bound(%State{} = state) do
    case state.handler.handle_bound(state.handler_state) do
      {:noreply, handler_state} ->
        {:noreply, %{state | handler_state: handler_state}}
    end
  end

  def handle_call(message, from, %State{} = state) do
    case state.handler.handle_call(message, from, state.handler_state) do
      {:noreply, handler_state} ->
        {:noreply, %{state | handler_state: handler_state}}

      {:reply, reply, handler_state} ->
        {:reply, reply, %{state | handler_state: handler_state}}

      {:stop, reason, handler_state} ->
        {:stop, reason, %{state | handler_state: handler_state}}
    end
  end

  def handle_cast(message, %State{} = state) do
    case state.handler.handle_cast(message, state.handler_state) do
      {:noreply, handler_state} ->
        {:noreply, %{state | handler_state: handler_state}}

      {:stop, reason, handler_state} ->
        {:stop, reason, %{state | handler_state: handler_state}}
    end
  end

  def handle_info(message, %State{} = state) do
    case state.handler.handle_info(message, state.handler_state) do
      {:noreply, handler_state} ->
        {:noreply, %{state | handler_state: handler_state}}

      {:stop, reason, handler_state} ->
        {:stop, reason, %{state | handler_state: handler_state}}
    end
  end

  def handle_message(source, %Message{} = message, %State{} = state) do
    case state.handler.handle_message(source, message, state.handler_state) do
      {:ok, handler_state} ->
        {:ok, %{state | handler_state: handler_state}}

      {:stop, reason, handler_state} ->
        {:stop, reason, %{state | handler_state: handler_state}}
    end
  end
end
