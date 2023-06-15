defmodule ExSip.MessageTest do
  use ExUnit.Case

  alias ExSip.Message

  describe "decode/1 & encode/1" do
    test "can decode a message" do
      blob = """
      OPTIONS sip:12003005000@example.com SIP/2.0\r
      Via: SIP/2.0/UDP 127.0.0.1:5060\r
      From: <sip:555@127.0.0.1:5060>\r
      To: <sip:12003005000@example.com>\r
      Call-ID: abc@127.0.0.1:5060\r
      CSeq: 101 OPTIONS\r
      Content-Length: 0\r
      \r
      """

      assert {:ok, message} = Message.decode(blob)

      assert %Message{
        type: :request,
        start_line: %{
          method: "OPTIONS",
          url: "sip:12003005000@example.com",
          version: "SIP/2.0",
        },
        headers: [
          {"Via", "SIP/2.0/UDP 127.0.0.1:5060"},
          {"From", "<sip:555@127.0.0.1:5060>"},
          {"To", "<sip:12003005000@example.com>"},
          {"Call-ID", "abc@127.0.0.1:5060"},
          {"CSeq", "101 OPTIONS"},
          {"Content-Length", "0"},
        ]
      } = message

      {:ok, blob} = Message.encode(message)
      assert """
      OPTIONS sip:12003005000@example.com SIP/2.0\r
      Via: SIP/2.0/UDP 127.0.0.1:5060\r
      From: <sip:555@127.0.0.1:5060>\r
      To: <sip:12003005000@example.com>\r
      Call-ID: abc@127.0.0.1:5060\r
      CSeq: 101 OPTIONS\r
      Content-Length: 0\r
      \r
      """ == IO.iodata_to_binary(blob)
    end
  end

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
