defmodule ExSip.Handler do
  defmacro __using__(_opts) do
    quote do
      @behaviour ExSip.Handler

      @doc false
      def init(args) do
        {:ok, args}
      end

      @doc false
      def terminate(_reason, _state) do
        :ok
      end

      @doc false
      def handle_bound(state) do
        {:ok, state}
      end

      @doc false
      def handle_message(_message, state) do
        {:ok, state}
      end

      defoverridable [init: 1, terminate: 2, handle_bound: 1, handle_message: 2]
    end
  end

  alias ExSip.Listeners.State
  alias ExSip.Message

  @callback init(args::any()) :: {:ok, any()}

  @callback terminate(reason::any(), args::any()) :: any()

  @callback handle_bound(state::any()) :: {:ok, any()}

  @callback handle_message(Message.t(), state::any()) :: {:ok, any()}

  def init(args, %State{} = state) do
    case state.handler.init(args) do
      {:ok, handler_state} ->
        {:ok, %{state | handler_state: handler_state}}
    end
  end

  def terminate(reason, %State{} = state) do
    case state.handler.terminate(reason, state.handler_state) do
      {:ok, handler_state} ->
        {:ok, %{state | handler_state: handler_state}}
    end
  end

  def handle_bound(%State{} = state) do
    case state.handler.handle_bound(state.handler_state) do
      {:ok, handler_state} ->
        {:ok, %{state | handler_state: handler_state}}
    end
  end

  def handle_message(%Message{} = message, %State{} = state) do
    case state.handler.handle_message(message, state.handler_state) do
      {:ok, handler_state} ->
        {:ok, %{state | handler_state: handler_state}}
    end
  end
end
