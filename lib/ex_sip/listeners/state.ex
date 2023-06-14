defmodule ExSip.Listeners.State do
  defstruct [
    handler: nil,
    handler_state: nil,
    waiting_for_bind: :queue.new(),
    socket: nil,
    receiver: nil,
  ]
end
