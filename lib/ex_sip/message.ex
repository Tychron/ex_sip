defmodule ExSip.Message do
  defstruct [
    type: :unknown,
    start_line: nil,
    headers: [],
    body: nil,
  ]

  alias __MODULE__, as: Message

  def parse(blob) when is_binary(blob) do
    case :binary.split(blob, "\r\n") do
      [start_line, rest] ->
        {type, start_line} =
          case parse_start_line(start_line) do
            {:ok, type, data} ->
              {type, data}
          end

        {:ok, headers, rest} = parse_headers(rest)
        message = %Message{
          type: type,
          start_line: start_line,
          headers: headers,
          body: rest
        }
        {:ok, message}
    end
  end

  def parse_start_line(blob) when is_binary(blob) do
    [head, blob] = :binary.split(blob, "\s")
    [mid, tail] = :binary.split(blob, "\s")

    case String.upcase(head) do
      "SIP/" <> _ ->
        {:ok, :response, %{version: head, status_code: mid, reason: tail}}

      _ ->
        {:ok, :request, %{method: head, url: mid, version: tail}}
    end
  end

  def parse_headers(blob) when is_binary(blob) do
    do_parse_headers(blob, [])
  end

  defp do_parse_headers(<<"\r\n", rest::binary>>, acc) do
    {:ok, Enum.reverse(acc), rest}
  end

  defp do_parse_headers(<<"\s", _rest::binary>> = blob, acc) do
    blob = String.trim_leading(blob, "\s")
    case :binary.split(blob, "\r\n") do
      [appendage, rest] ->
        [{key, value} | acc] = acc
        acc = [{key, value <> appendage} | acc]
        do_parse_headers(rest, acc)
    end
  end

  defp do_parse_headers(blob, acc) when is_binary(blob) do
    case :binary.split(blob, "\r\n") do
      ["\r\n", rest] ->
        {:ok, Enum.reverse(acc), rest}

      [header, rest] ->
        case parse_header(header) do
          {:ok, {key, value}} ->
            do_parse_headers(rest, [{key, value} | acc])
        end
    end
  end

  defp parse_header(blob) when is_binary(blob) do
    case :binary.split(blob, ":") do
      [key, value] ->
        {:ok, {key, String.trim_leading(value)}}
    end
  end
end
