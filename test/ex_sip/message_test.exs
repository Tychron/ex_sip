defmodule ExSip.MessageTest do
  use ExUnit.Case

  alias ExSip.Message

  describe "get_header/2 & put_header/3" do
    test "can put a new header in message" do
      message = %Message{}

      message = Message.put_header(message, "to", "<sip:555@example.com>")

      assert "<sip:555@example.com>" == Message.get_header(message, "to")

      assert [
        {"to", "<sip:555@example.com>"}
      ] = message.headers
    end

    test "can overwrite a header" do
      message = %Message{}

      message = Message.put_header(message, "to", "<sip:555@example.com>")
      assert "<sip:555@example.com>" == Message.get_header(message, "to")

      message = Message.put_header(message, "to", "<sip:18002223333@example.com>")
      assert "<sip:18002223333@example.com>" == Message.get_header(message, "to")

      assert [
        {"to", "<sip:18002223333@example.com>"}
      ] = message.headers
    end
  end

  describe "append_header/3" do
    test "can append a new header to message" do
      message = %Message{}

      message = Message.append_header(message, "via", "SIP/2.0/UDP 10.0.0.117:5060")
      assert [
        {"via", "SIP/2.0/UDP 10.0.0.117:5060"}
      ] = message.headers

      message = Message.append_header(message, "via", "SIP/2.0/UDP 10.0.0.118:5060")
      assert [
        {"via", "SIP/2.0/UDP 10.0.0.117:5060"},
        {"via", "SIP/2.0/UDP 10.0.0.118:5060"},
      ] = message.headers

      message = Message.append_header(message, "via", "SIP/2.0/UDP 10.0.0.119:5060")
      assert [
        {"via", "SIP/2.0/UDP 10.0.0.117:5060"},
        {"via", "SIP/2.0/UDP 10.0.0.118:5060"},
        {"via", "SIP/2.0/UDP 10.0.0.119:5060"},
      ] = message.headers
    end

    test "will correctly interleave headers" do
      message = %Message{
        headers: [
          {"from", "<sip:18002221234@10.0.0.115:5060>"},
          {"to", "<sip:555@10.0.0.116:5060>"},
          {"via", "SIP/2.0/UDP 10.0.0.117:5060"},
          {"call-id", "abc123@10.0.0.115:5060"},
        ]
      }

      message = Message.append_header(message, "via", "SIP/2.0/UDP 10.0.0.119:5060")
      assert [
        {"from", "<sip:18002221234@10.0.0.115:5060>"},
        {"to", "<sip:555@10.0.0.116:5060>"},
        {"via", "SIP/2.0/UDP 10.0.0.117:5060"},
        {"via", "SIP/2.0/UDP 10.0.0.119:5060"},
        {"call-id", "abc123@10.0.0.115:5060"},
      ] = message.headers
    end
  end

  describe "prepend_header/3" do
    test "can append a new header to message" do
      message = %Message{}

      message = Message.prepend_header(message, "via", "SIP/2.0/UDP 10.0.0.117:5060")
      assert [
        {"via", "SIP/2.0/UDP 10.0.0.117:5060"}
      ] = message.headers

      message = Message.prepend_header(message, "via", "SIP/2.0/UDP 10.0.0.118:5060")
      assert [
        {"via", "SIP/2.0/UDP 10.0.0.118:5060"},
        {"via", "SIP/2.0/UDP 10.0.0.117:5060"}
      ] = message.headers

      message = Message.prepend_header(message, "via", "SIP/2.0/UDP 10.0.0.119:5060")
      assert [
        {"via", "SIP/2.0/UDP 10.0.0.119:5060"},
        {"via", "SIP/2.0/UDP 10.0.0.118:5060"},
        {"via", "SIP/2.0/UDP 10.0.0.117:5060"}
      ] = message.headers
    end

    test "will correctly interleave headers" do
      message = %Message{
        headers: [
          {"from", "<sip:18002221234@10.0.0.115:5060>"},
          {"to", "<sip:555@10.0.0.116:5060>"},
          {"via", "SIP/2.0/UDP 10.0.0.117:5060"},
          {"call-id", "abc123@10.0.0.115:5060"},
        ]
      }

      message = Message.prepend_header(message, "via", "SIP/2.0/UDP 10.0.0.119:5060")
      assert [
        {"from", "<sip:18002221234@10.0.0.115:5060>"},
        {"to", "<sip:555@10.0.0.116:5060>"},
        {"via", "SIP/2.0/UDP 10.0.0.119:5060"},
        {"via", "SIP/2.0/UDP 10.0.0.117:5060"},
        {"call-id", "abc123@10.0.0.115:5060"},
      ] = message.headers
    end
  end
end
