defmodule ExSip.Clients.State do
  defstruct [
    handler: nil,
    handler_state: nil,
    socket: nil,
  ]

  @type t :: %__MODULE__{
    handler: module(),
    handler_state: any(),
    socket: :socket.socket(),
  }
end
