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

                            case ExSip.RFC2045.Attributes.parse(";" <> parameters) do
                              {parameters, rest} ->
                                parameters =
                                  if options[:normalize_parameters] do
                                    Enum.map(parameters, fn {key, value} ->
                                      {String.downcase(key), value}
                                    end)
                                  else
                                    parameters
                                  end

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

  @spec get_parameter(t(), key::String.t()) :: any()
  def get_parameter(%Via{} = via, key) do
    ExSip.Proplist.get(via.parameters, key)
  end

  @spec put_parameter(t(), key::String.t(), value::any()) :: Via.t()
  def put_parameter(%Via{} = via, key, value) do
    %{
      via
      | parameters: ExSip.Proplist.put(via.parameters, key, value)
    }
  end
end
