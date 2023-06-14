defmodule ExSip.Headers.ViaTest do
  use ExUnit.Case

  alias ExSip.Headers.Via

  describe "decode/1" do
    test "can decode a simple via header" do
      assert {:ok, %Via{
        protocol: "SIP",
        version: "2.0",
        transport: "UDP",
        url: "10.0.0.115:5070",
        parameters: [],
      }, ""} == Via.decode("SIP/2.0/UDP 10.0.0.115:5070")
    end

    test "can decode a spaced via header" do
      assert {:ok, %Via{
        protocol: "SIP",
        version: "2.0",
        transport: "UDP",
        url: "10.0.0.115: 5070",
        parameters: [
          {"branch", "z9hG4bKabcdef22"}
        ],
      }, ""} == Via.decode(
        "SIP / 2.0 / UDP 10.0.0.115: 5070;BRANCH=z9hG4bKabcdef22",
        normalize_parameters: true
      )
    end
  end
end
