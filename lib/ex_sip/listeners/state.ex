defmodule ExSip.Listeners.State do
  defstruct [
    port: nil,
    addr: nil,
    handler: nil,
    handler_state: nil,
    waiting_for_bind: :queue.new(),
    socket: nil,
    receiver: nil,
  ]

  @type t :: %__MODULE__{
    port: non_neg_integer(),
    addr: :socket.sockaddr(),
    handler: module(),
    handler_state: any(),
    waiting_for_bind: :queue.queue(),
    socket: :socket.socket(),
    receiver: pid(),
  }
end
