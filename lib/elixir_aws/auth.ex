defmodule Aws.Auth.Signature.V4 do

  def sign(region, service, http_method, uri, headers, payload, query \\ "") do
    date = iso_8601(:date)
    configs = Aws.Config.get()
    secret = configs.secret
    
    if secret != nil do
      signing_key = hmac_sha256("AWS4" <> secret, date)
      |> hmac_sha256(region)
      |> hmac_sha256(service)
      |> hmac_sha256("aws4_request")
      
      string_to_sign = string_to_sign(region, service, http_method, uri, headers, payload, query)
      |> digest

      hmac_sha256(signing_key, string_to_sign)
      |> digest
    else
      {:error, :no_secret_key_found}
    end
  end
  
  def string_to_sign(region, service, http_method, uri, headers, payload, query \\ "") do    
    datetime = iso_8601(:datetime)
    [date, _] = String.split(datetime, "T")
    
    headers = [{"X-Amz-Date", date} | headers]
    cr_string = canonical_request(http_method, uri, headers, payload, query)
    hash = digest(cr_string)
    
    "AWS4-HMAC-SHA256\n#{datetime}\n#{date}/#{region}/#{service}/aws4_request\n#{hash}"
  end

  def canonical_request(http_method, uri, headers, payload, query \\ "") do
    {signed_headers, canonical_headers} = canonical_headers(headers)
    payload = digest(payload)
    "#{http_method}\n#{uri}\n#{query}\n#{canonical_headers}\n#{signed_headers}\n#{payload}"
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

  def digest(data) do
    [digest] = :io_lib.format(
      '~64.16.0b',
      [:binary.decode_unsigned(:crypto.hash(:sha256, data))])
    List.to_string(digest)
  end
  
  def iso_8601(:datetime) do
    {{year, month, day}, {hour, min, sec}} = :calendar.now_to_universal_time(:os.timestamp())
    :lists.flatten(:io_lib.format('~4.10.0B~2.10.0B~2.10.0BT~2.10.0B~2.10.0B~2.10.0BZ',
                                  [year, month, day, hour, min, sec]))
    |> List.to_string
  end

  def iso_8601(:date) do
    {{year, month, day}, {_, _, _}} = :calendar.now_to_universal_time(:os.timestamp())
    :lists.flatten(:io_lib.format('~4.10.0B~2.10.0B~2.10.0B',
                                  [year, month, day]))
    |> List.to_string
  end

  def hmac_sha256(key, data) do
    :crypto.hmac(:sha256, key, data)
  end
  
end
