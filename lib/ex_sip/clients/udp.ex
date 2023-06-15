defmodule ExSip.Clients.UDP do
  require Logger

  alias ExSip.Clients.Handler
  alias ExSip.Message
  alias ExSip.Clients.State

  @spec open(Keyword.t()) :: {:ok, State.t()} | {:error, term()}
  def open(options) do
    options = extract_open_options!(options)

    {handler, args} = Keyword.fetch!(options, :handler)
    state = %State{
      transport: :udp,
      handler: handler,
      socket: nil
    }

    case :socket.open(:inet, :dgram, :udp, %{}) do
      {:ok, socket} ->
        state = %{state | socket: socket}
        try do
          case Handler.init(args, socket, state) do
            {:ok, state} ->
              {:ok, state}
          end
        rescue ex ->
          :socket.close(socket)
          reraise ex, __STACKTRACE__
        end

      {:error, _} = err ->
        err
    end
  end

  @spec close(State.t()) :: {:ok, State.t()} | {{:error, term()}, State.t()}
  def close(%State{socket: socket} = state) do
    case :socket.close(socket) do
      :ok ->
        Handler.handle_closed(state)

      {:error, _reason} = err ->
        {err, state}
    end
  end

  @spec send_to(State.t(), Message.t() | iodata(), :socket.sockaddr()) ::
    {:ok, State.t()}
    | {{:error, term()}, State.t()}
  def send_to(%State{} = state, %Message{} = message, dest) do
    case Handler.encode_message(message, state) do
      {:ok, blob, state} ->
        send_to(state, blob, dest)
    end
  end

  def send_to(%State{socket: socket} = state, blob, dest) do
    case :socket.sendto(socket, blob, dest) do
      :ok ->
        {:ok, state}

      {:error, _reason} = err ->
        {err, state}
    end
  end

  defp extract_open_options!(options) do
    case Keyword.fetch!(options, :handler) do
      {handler, args} ->
        [
          handler: {handler, args},
        ]
    end
  end
end
