defmodule ExSip.Clients.Handler do
  defmacro __using__(_opts) do
    quote do
      @behaviour ExSip.Clients.Handler

      @doc false
      def init(args, _socket) do
        {:ok, args}
      end

      @doc false
      def handle_closed(state) do
        {:ok, state}
      end

      @doc false
      def encode_message(message, state) do
        case ExSip.Message.encode(message) do
          {:ok, blob} ->
            {:ok, blob, state}
        end
      end

      defoverridable ExSip.Clients.Handler
    end
  end

  alias ExSip.Listeners.State
  alias ExSip.Message

  @callback init(any(), :socket.socket()) :: {:ok, any()} | {:error, term()}

  @callback handle_closed(args::any()) :: {:ok, any()}

  @callback encode_message(Message.t(), state::any()) :: {:ok, iodata(), any()}

  def init(args, socket, %State{} = state) do
    case state.handler.init(args, socket) do
      {:ok, handler_state} ->
        {:ok, %{state | handler_state: handler_state}}
    end
  end

  def handle_closed(%State{} = state) do
    case state.handler.handle_closed(state.handler_state) do
      {:ok, handler_state} ->
        {:ok, %{state | handler_state: handler_state}}
    end
  end

  def encode_message(%Message{} = message, %State{} = state) do
    case state.handler.encode_message(message, state.handler_state) do
      {:ok, blob, handler_state} ->
        {:ok, blob, %{state | handler_state: handler_state}}
    end
  end
end
