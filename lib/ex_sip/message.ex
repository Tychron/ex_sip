defmodule ExSip.Message do
  defstruct [
    type: :unknown,
    start_line: nil,
    headers: [],
    body: nil,
  ]

  @type request_start_line :: %{
    method: String.t(),
    url: String.t(),
    version: String.t(),
  }

  @type response_start_line :: %{
    version: String.t(),
    status_code: String.t(),
    reason: String.t()
  }

  @typedoc """
  Typically after decode the header will always be a string.

  But over the source of normalizing and performing secondary-decodes on each value, it can
  gradually change.
  """
  @type header_value :: String.t() | any()

  @type header :: {key::String.t(), header_value()}

  @type headers :: [header()]

  @type t :: %__MODULE__{
    type: :request | :response | :unknown,
    start_line: request_start_line() | response_start_line(),
    headers: headers(),
    body: iodata(),
  }

  alias __MODULE__, as: Message
  alias ExSip.Proplist

  @doc """
  Typically headers are decoded as-is from the original blob with no additional post-processing
  applied.

  One useful postprocess is to normalize (or downcase) all header keys to improve lookup.

  Usage:

      message = Message.normalize_headers(message)

      vias = Proplist.all(message.headers, "via")

  """
  @spec normalize_headers(Message.t()) :: Message.t()
  def normalize_headers(%Message{} = message) do
    %{
      message
      | headers: Enum.map(message.headers, fn {key, value} ->
        {String.downcase(key), value}
      end)
    }
  end

  @doc """
  If, for some reason your SIP server/client doesn't like downcased key names, this function
  is provided to undo the action of normalize_headers, not that unrecognized keys will remain
  in their original casing.

  Optionally a fallback function can be provided to normalize keys that weren't handled by
  unnormalize_header_key/1.

  Usage:

      message = Message.unnormalize_headers(message)

  """
  @spec unnormalize_headers(Message.t()) :: Message.t()
  def unnormalize_headers(%Message{} = message) do
    unnormalize_headers(message, &unnormalize_header_fallback/1)
  end

  @spec unnormalize_headers(Message.t()) :: Message.t()
  def unnormalize_headers(%Message{} = message, fallback) when is_function(fallback, 1) do
    %{
      message
      | headers: Enum.map(message.headers, fn {key, value} ->
        case unnormalize_header_key(key) do
          {:ok, key} ->
            {key, value}

          :error ->
            {fallback.(key), value}
        end
      end)
    }
  end

  defp unnormalize_header_fallback(blob) do
    blob
  end

  @spec unnormalize_header_key(String.t()) :: {:ok, String.t()} | :error
  def unnormalize_header_key("allow"), do: {:ok, "Allow"}
  def unnormalize_header_key("call-id"), do: {:ok, "Call-ID"}
  def unnormalize_header_key("contact"), do: {:ok, "Contact"}
  def unnormalize_header_key("content-disposition"), do: {:ok, "Content-Disposition"}
  def unnormalize_header_key("content-length"), do: {:ok, "Content-Length"}
  def unnormalize_header_key("content-type"), do: {:ok, "Content-Type"}
  def unnormalize_header_key("cseq"), do: {:ok, "CSeq"}
  def unnormalize_header_key("from"), do: {:ok, "From"}
  def unnormalize_header_key("max-forwards"), do: {:ok, "Max-Forwards"}
  def unnormalize_header_key("route"), do: {:ok, "Route"}
  def unnormalize_header_key("server"), do: {:ok, "Server"}
  def unnormalize_header_key("subject"), do: {:ok, "Subject"}
  def unnormalize_header_key("supported"), do: {:ok, "Supported"}
  def unnormalize_header_key("to"), do: {:ok, "To"}
  def unnormalize_header_key("user-agent"), do: {:ok, "User-Agent"}
  def unnormalize_header_key("via"), do: {:ok, "Via"}
  def unnormalize_header_key(_) do
    :error
  end

  @doc """
  Replaces a single header.

  If you intended to append/prepend a header, there are functions for that instead.

  Usage:

      message = Message.put_header(message, "to", "<sip:555@example.com>")

      message = Message.put_header(message, "via", "SIP/2.0/UDP example.com:5060;branch=abcdefasd")

  """
  @spec put_header(Message.t(), String.t(), any()) :: t()
  def put_header(%Message{} = message, key, value) do
    %{
      message
      | headers: Proplist.put(message.headers, key, value)
    }
  end

  @spec append_header(Message.t(), String.t(), t()) :: t()
  def append_header(%Message{} = message, key, value) do
    %{
      message
      | headers: Proplist.append_local(message.headers, key, value)
    }
  end

  @spec prepend_header(Message.t(), String.t(), t()) :: t()
  def prepend_header(%Message{} = message, key, value) do
    %{
      message
      | headers: Proplist.prepend_local(message.headers, key, value)
    }
  end

  @doc """
  Retrieve a single header by key, note that this is case-sensitive.

  Usage:

      value = Message.get_header(message, "to")

  """
  @spec get_header(Message.t(), String.t()) :: any()
  def get_header(%Message{} = message, key) do
    Proplist.get(message.headers, key)
  end

  @doc """
  Retrieve the values for specified header key

  Usage:

      values = Message.all_headers(message, "via")

  """
  @spec all_headers(Message.t(), String.t()) :: [any()]
  def all_headers(%Message{} = message, key) do
    Proplist.all(message.headers, key)
  end

  @doc """
  Decode a blob into a Message.

  Options:
  * `normalize_headers` - immediately normalize header fields by downcasing them

  Usage:

    {:ok, message} = Message.decode(blob)

    {:ok, message} = Message.decode(blob, normalize_headers: true)

  """
  @spec decode(binary(), Keyword.t()) :: {:ok, Message.t()}
  def decode(blob, options \\ []) when is_binary(blob) do
    case :binary.split(blob, "\r\n") do
      [start_line, rest] ->
        {type, start_line} =
          case decode_start_line(start_line) do
            {:ok, type, data} ->
              {type, data}
          end

        {:ok, headers, rest} = decode_headers(rest, options)
        message = %Message{
          type: type,
          start_line: start_line,
          headers: headers,
          body: rest
        }
        {:ok, message}
    end
  end

  def decode_start_line(blob) when is_binary(blob) do
    [head, blob] = :binary.split(blob, "\s")
    [mid, tail] = :binary.split(blob, "\s")

    case String.upcase(head) do
      "SIP/" <> _ ->
        {:ok, :response, %{version: head, status_code: mid, reason: tail}}

      _ ->
        {:ok, :request, %{method: head, url: mid, version: tail}}
    end
  end

  def decode_headers(blob, options) when is_binary(blob) do
    do_decode_headers(blob, [], options)
  end

  @doc """
  Encode the message as-is, this will not adjust the content-length or any other headers.

  Usage:

      {:ok, iodata} = Message.encode(message)

      :socket.send(socket, iodata)

  """
  @spec encode(Message.t()) :: {:ok, iodata()}
  def encode(%Message{} = message) do
    {:ok, start_line} = encode_start_line(message.type, message.start_line)

    headers = encode_headers(message.headers)

    {:ok, [
      start_line, "\r\n",
      headers,
      "\r\n",
      message.body || []
    ]}
  end

  def encode_start_line(:request, start_line) do
    %{
      method: method,
      url: url,
      version: version,
    } = start_line

    {:ok, [method, "\s", url, "\s", version]}
  end

  def encode_start_line(:response, start_line) do
    %{
      version: version,
      status_code: status_code,
      reason: reason,
    } = start_line

    {:ok, [version, "\s", status_code, "\s", reason]}
  end

  def encode_headers(headers) do
    Enum.map(headers, fn {key, value} ->
      [key, ": ", value, "\r\n"]
    end)
  end

  defp do_decode_headers(<<"\r\n", rest::binary>>, acc, _options) do
    {:ok, Enum.reverse(acc), rest}
  end

  defp do_decode_headers(<<"\s", _rest::binary>> = blob, acc, options) do
    blob = String.trim_leading(blob, "\s")
    case :binary.split(blob, "\r\n") do
      [appendage, rest] ->
        [{key, value} | acc] = acc
        acc = [{key, value <> appendage} | acc]
        do_decode_headers(rest, acc, options)
    end
  end

  defp do_decode_headers(blob, acc, options) when is_binary(blob) do
    case :binary.split(blob, "\r\n") do
      ["\r\n", rest] ->
        {:ok, Enum.reverse(acc), rest}

      [header, rest] ->
        case decode_header(header, options) do
          {:ok, {key, value}} ->
            do_decode_headers(rest, [{key, value} | acc], options)
        end
    end
  end

  defp decode_header(blob, options) when is_binary(blob) do
    case :binary.split(blob, ":") do
      [key, value] ->
        key =
          if options[:normalize_headers] do
            String.downcase(key)
          else
            key
          end

        {:ok, {key, String.trim_leading(value)}}
    end
  end
end
