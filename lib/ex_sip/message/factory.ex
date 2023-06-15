defmodule ExSip.Message.Factory do
  alias ExSip.Message

  def request(method, url) do
    %Message{
      type: :request,
      start_line: %{
        method: String.upcase(to_string(method)),
        url: url,
        version: "SIP/2.0"
      }
    }
  end

  def options_request(url, options) do
    message = request("OPTIONS", url)

    message =
      Enum.reduce(options[:vias], message, fn
        via, message when is_binary(via) ->
          Message.append_header(message, "via", via)
      end)

    message =
      message
      |> Message.append_header("from", options[:from])
      |> Message.append_header("to", options[:to])
      |> Message.append_header("call-id", "123459@example.com")
      |> Message.append_header("cseq", "101 OPTIONS")
      |> Message.append_header("max-forwards", "70")
      |> Message.append_header("content-length", "0")

    message
  end
end
