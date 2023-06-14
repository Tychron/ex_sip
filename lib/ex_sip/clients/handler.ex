defmodule ExSip.Clients.Handler do
  defmacro __using__(_opts) do
    quote do
      @behaviour ExSip.Clients.Handler

      @doc false
      def init(args) do
        {:ok, args}
      end

      @doc false
      def terminate(_reason, _state) do
        :ok
      end

      @doc false
      def encode_message(message, state) do
        case ExSip.Message.encode(message) do
          {:ok, blob} ->
            {:ok, blob, state}
        end
      end

      defoverridable [init: 1, terminate: 2, encode_message: 2]
    end
  end

  alias ExSip.Listeners.State
  alias ExSip.Message

  @callback init(args::any()) :: {:ok, any()}

  @callback terminate(reason::any(), args::any()) :: any()

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

  def encode_message(%Message{} = message, %State{} = state) do
    case state.handler.encode_message(message, state.handler_state) do
      {:ok, blob, handler_state} ->
        {:ok, blob, %{state | handler_state: handler_state}}
    end
  end
end
