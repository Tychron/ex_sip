defmodule ExSip.Clients.UDPTest do
  defmodule TestHandler do
    use ExSip.Clients.Handler
  end

  use ExUnit.Case

  describe "open/1" do
    test "can open a new udp client connection" do
      {:ok, client} = ExSip.Clients.UDP.open(handler: {TestHandler, :ok})
      try do
        :ok
      after
        ExSip.Clients.UDP.close(client)
      end
    end
  end
end
