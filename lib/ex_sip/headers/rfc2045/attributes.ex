defmodule ExSip.RFC2045.Attributes do
  @moduledoc """
  Modified RFC2045 attributes module for handling SIP header attributes.

  According to the RFC, the parameters must take the form key=value, however SIPs seems to allow
  key-only parameters as well, so that's fun.
  """
  @typedoc """
  Attribute values are either a binary (meaning the value was explictly given) or true, where
  it would be a key-only attribute.
  """
  @type attribute_value :: binary() | boolean()

  @typedoc """
  Attributes are simple key-value pairs.
  """
  @type attribute :: {key::binary(), attribute_value()}

  @token_regex ~r/\A[!#\$%&'*+\-\.0-9A-Z\^_`a-z|~]+/

  @spec parse_token(binary) :: {binary, binary} | nil
  def parse_token(binary) do
    case String.split(binary, @token_regex, parts: 2, include_captures: true) do
      [_, token, rest] -> {token, rest}
      _ -> nil
    end
  end

  @spec parse_quoted_string(binary) :: {binary, binary} | nil
  @spec parse_quoted_string(binary, atom, list) :: {binary, binary} | nil
  def parse_quoted_string(binary, state \\ :start, acc \\ [])

  def parse_quoted_string(rest, :end, acc) do
    result =
      acc
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    {result, rest}
  end

  def parse_quoted_string(<<"\"", rest::binary>>, :inner, acc) do
    parse_quoted_string(rest, :end, acc)
  end

  def parse_quoted_string(<<"\\", c::binary-size(1), rest::binary>>, :inner, acc) do
    parse_quoted_string(rest, :inner, [c | acc])
  end

  def parse_quoted_string(<<c::binary-size(1), rest::binary>>, :inner, acc) do
    parse_quoted_string(rest, :inner, [c | acc])
  end

  def parse_quoted_string(<<"\"", rest::binary>>, :start, acc) do
    parse_quoted_string(rest, :inner, acc)
  end

  def parse_quoted_string(<<>>, :start, _acc) do
    nil
  end

  @doc """
  Parses as many attributes from the given string as possible.

  The string is expected to start a semi-colon (;) and any whitespaces
  # *(; attribute = value)
  """
  @spec parse(binary(), atom(), list()) ::
    {[attribute()], rest::binary()}
  def parse(rest, state \\ :next, acc \\ [])

  def parse(rest, :end, acc) do
    {Enum.reverse(acc), rest}
  end

  def parse(<<" ", rest::binary>>, :next, acc) do
    parse(String.trim_leading(rest), :next, acc)
  end

  def parse(<<?;, rest::binary>> = unparsed, :next, acc) do
    rest = String.trim_leading(rest)

    case parse_token(rest) do
      nil ->
        parse(unparsed, :end, acc)

      {key, rest} ->
        case String.trim_leading(rest) do
          <<?=, rest::binary>> ->
            rest = String.trim_leading(rest)

            with nil <- parse_token(rest),
                 nil <- parse_quoted_string(rest) do
              parse(unparsed, :end, acc)
            else
              {value, rest} ->
                parse(rest, :next, [{key, value} | acc])
            end

          rest ->
            parse(rest, :next, [{key, true} | acc])
        end
    end
  end

  def parse(rest, :next, acc) do
    parse(rest, :end, acc)
  end
end
