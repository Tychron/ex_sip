defmodule ExSip.URI do
  defstruct [
    ip: nil,
    host: nil,
    port: nil,
  ]

  @type t :: %__MODULE__{
    ip: tuple(),
    host: String.t(),
    port: integer()
  }

  @spec parse(binary()) :: {:ok, t()}
  def parse(bin) when is_binary(bin) do
    uri =
      case String.split(bin, ":", parts: 2) do
        [host, port] ->
          host = String.trim(host)
          port = String.to_integer(String.trim(port), 10)

          %__MODULE__{
            host: host,
            port: port,
          }

        [host] ->
          host = String.trim(host)
          %__MODULE__{
            host: host,
            port: nil,
          }
      end

    uri =
      %{
        uri
        | ip: case :inet.parse_address(to_charlist(uri.host)) do
          {:ok, ip} ->
            ip

          {:error, :einval} ->
            nil
        end,
      }

    {:ok, uri}
  end
end
