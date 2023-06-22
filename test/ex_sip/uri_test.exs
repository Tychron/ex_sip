defmodule ExSip.URITest do
  use ExUnit.Case

  alias ExSip.URI, as: SIPURI

  describe "parse/1" do
    test "can parse a simple SIP URI" do
      assert {:ok, %SIPURI{
        host: "10.0.0.115",
        ip: {10, 0, 0, 115},
        port: nil
      }} = SIPURI.parse("10.0.0.115")
    end

    test "can parse a SIP URI with port" do
      assert {:ok, %SIPURI{
        host: "10.0.0.115",
        ip: {10, 0, 0, 115},
        port: 5060
      }} = SIPURI.parse("10.0.0.115:5060")
    end
  end
end
