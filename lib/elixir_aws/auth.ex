defmodule Aws.Auth.Utils do

  def hmac_sha256(key, data) do
    :crypto.hmac(:sha256, key, data)
  end
  
  def sha256(data) do
    :crypto.hash(:sha256, data)
  end

  def hexdigest(data) do
    :io_lib.format(
      '~64.16.0b',
      [:binary.decode_unsigned(data)])
    |> List.to_string
  end
    
  def iso_8601_date() do
    {{year, month, day}, {hour, min, sec}} = :calendar.now_to_universal_time(:os.timestamp())
    :lists.flatten(:io_lib.format('~4.10.0B~2.10.0B~2.10.0BT~2.10.0B~2.10.0B~2.10.0BZ',
                                  [year, month, day, hour, min, sec]))
    |> List.to_string
  end
  
end

defmodule Aws.Auth.Signature.V4 do

  import Aws.Auth.Utils

  @spec sign(request :: Aws.Http.Request.t, region :: binary, service :: binary) :: Aws.Http.Request.t
  def sign(request, region, service) do
    {_, datetime} = List.keyfind(request.headers, "x-amz-date", 0, {"x-amz-date", iso_8601_date()})
    [date, _] = String.split(datetime, "T")
    configs = Aws.Config.get()
    secret = configs.secret

    if secret != nil do
      signing_key = hmac_sha256("AWS4" <> secret, date)
      |> hmac_sha256(region)
      |> hmac_sha256(service)
      |> hmac_sha256("aws4_request")

      headers = List.keystore(request.headers, "x-amz-date", 0, {"x-amz-date", datetime})
      request = %{request | :headers => headers}
      {signed_headers, cr_string} = canonical_request(request)

      string_to_sign = string_to_sign(region, service, datetime, date, cr_string)

      signature = hmac_sha256(signing_key, string_to_sign)
      |> hexdigest
      
      credential_scope = "#{date}/#{region}/#{service}/aws4_request"
      
      auth_header = "AWS4-HMAC-SHA256 Credential=#{configs.key}/#{credential_scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"
      
      {:ok, %{request | :headers => [{"Authorization", auth_header} | request.headers]}}
    else
      {:error, :no_secret_key_found}
    end
  end
  
  def string_to_sign(region, service, datetime, date, canonical_request) do
    hash = sha256(canonical_request)
    |> hexdigest
    "AWS4-HMAC-SHA256\n#{datetime}\n#{date}/#{region}/#{service}/aws4_request\n#{hash}"
  end

  def canonical_request(request) do
    {signed_headers, canonical_headers} = canonical_headers(request.headers)
    payload = sha256(request.payload)
    |> hexdigest
    canonical_string =
      "#{request.method}\n#{request.uri.path}\n#{request.query}\n#{canonical_headers}\n#{signed_headers}\n#{payload}"
    {signed_headers, canonical_string}
  end
  
  def canonical_headers(headers) do
    {signed_headers, canonical_headers} = Enum.map(headers,
      fn {header, value} ->
        {String.downcase(header), String.strip(value)}
      end)
    |> Enum.sort
    |> Enum.map_reduce("",
      fn ({header, value}, acc) ->
        {header, acc <> "#{header}:#{value}\n"}
      end)
    {Enum.join(signed_headers, ";"), canonical_headers}
  end
  
end
