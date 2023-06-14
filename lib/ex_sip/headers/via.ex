defmodule ExSip.Headers.Via do
  defstruct [
    protocol: nil,
    version: nil,
    transport: nil,
    url: nil,
    parameters: [],
  ]

  @type t :: %__MODULE__{
    protocol: String.t(),
    version: String.t(),
    transport: String.t(),
    url: String.t(),
    parameters: [
      {String.t(), String.t()},
    ],
  }

  alias __MODULE__, as: Via

  @spec decode!(binary(), Keyword.t()) :: t()
  def decode!(blob, options \\ []) when is_binary(blob) do
    {:ok, via} = decode(blob, options)
    via
  end

  @spec decode(binary(), Keyword.t()) :: {:ok, t()}
  def decode(blob, options \\ []) when is_binary(blob) do
    blob = String.trim_leading(blob)

    case blob do
      <<protocol::binary-size(3), rest::binary>> ->
        case String.upcase(protocol) do
          "SIP" ->
            case String.trim_leading(rest, "\s") do
              <<"/", rest::binary>> ->
                case :binary.split(rest, "/") do
                  [version, rest] ->
                    version = String.trim(version)
                    rest = String.trim_leading(rest, "\s")

                    case :binary.split(rest, "\s") do
                      [transport, rest] ->
                        via = %Via{
                          protocol: protocol,
                          version: version,
                          transport: transport
                        }

                        case :binary.split(rest, ";") do
                          [sip_uri] ->
                            {:ok, %{via | url: sip_uri}, ""}

                          [sip_uri, parameters] ->
                            via = %{via | url: sip_uri}

                            case decode_parameters(parameters, options) do
                              {:ok, parameters, rest} ->
                                {:ok, %{via | parameters: parameters}, rest}
                            end
                        end
                    end
                end
            end

          value ->
            {:error, {:unexpected_protocol, value}}
        end

      value ->
        {:error, {:unexpected, value}}
    end
  end

  defp decode_parameters(blob, options, acc \\ [])

  defp decode_parameters("" = rest, _options, acc) do
    {:ok, Enum.reverse(acc), rest}
  end

  defp decode_parameters(blob, options, acc) do
    case :binary.split(blob, "=") do
      [key, rest] ->
        case decode_parameter_value(rest) do
          {:ok, value, rest} ->
            key =
              if options[:normalize_parameters] do
                String.downcase(key)
              else
                key
              end

            decode_parameters(rest, options, [{key, value} | acc])
        end
    end
  end

  @spec decode_parameter_value(binary(), atom(), list()) ::
    {:ok, value::binary(), rest::binary()}
    | {:error, :unterminated_dquote}
  defp decode_parameter_value(blob, state \\ :start, acc \\ [])

  defp decode_parameter_value(rest, :end, acc) do
    {:ok, IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end

  defp decode_parameter_value(<<"\"", rest::binary>>, :start, acc) do
    decode_parameter_value(rest, :dquote, acc)
  end

  defp decode_parameter_value(rest, :start, acc) do
    decode_parameter_value(rest, :term, acc)
  end

  defp decode_parameter_value(<<>>, :dquote, _acc) do
    {:error, :unterminated_dquote}
  end

  defp decode_parameter_value(<<"\\\"", rest::binary>>, :dquote, acc) do
    decode_parameter_value(rest, :dquote, ["\"" | acc])
  end

  defp decode_parameter_value(<<"\"", rest::binary>>, :dquote, acc) do
    decode_parameter_value(rest, :end, acc)
  end

  defp decode_parameter_value(<<c::utf8, rest::binary>>, :dquote, acc) do
    decode_parameter_value(rest, :dquote, [<<c::utf8>> | acc])
  end

  defp decode_parameter_value(<<"\s", rest::binary>>, :term, acc) do
    decode_parameter_value(rest, :end, acc)
  end

  defp decode_parameter_value(<<";", rest::binary>>, :term, acc) do
    decode_parameter_value(rest, :end, acc)
  end

  defp decode_parameter_value(<<>> = rest, :term, acc) do
    decode_parameter_value(rest, :end, acc)
  end

  defp decode_parameter_value(<<c::utf8, rest::binary>>, :term, acc) do
    decode_parameter_value(rest, :term, [<<c::utf8>> | acc])
  end
end
