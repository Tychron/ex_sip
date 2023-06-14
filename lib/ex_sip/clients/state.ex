defmodule ExSip.Clients.State do
  defstruct [
    transport: nil,
    handler: nil,
    handler_state: nil,
    socket: nil,
  ]

  @type t :: %__MODULE__{
    transport: :udp | :tcp,
    handler: module(),
    handler_state: any(),
    socket: :socket.socket(),
  }
end
