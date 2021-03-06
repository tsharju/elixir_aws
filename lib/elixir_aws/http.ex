defmodule Aws.Http do

  alias Aws.Auth.Signature
  
  defmodule Request do
    defstruct method: nil, uri: %URI{}, headers: [], payload: "", query: ""
    @type t :: %Request{method: binary, uri: URI.t, headers: List.t,
                        payload: binary, query: binary}
  end
  
  def request("rest-xml", endpoint_prefix, api_version, signature_version, args, spec) do
    configs = Aws.Config.get()
    endpoint = Aws.Endpoints.get(configs.region, endpoint_prefix)
    uri = URI.parse(endpoint.uri)
    uri = %{uri | :path => spec.http.requestUri |> render_uri_template(args)}

    payload = ""
    if args[:opts] != nil do
      if args[:opts][:payload] != nil do
        payload = args[:opts][:payload]
      end
    end
    
    req = %Request
    {
        :method => spec.http.method,
        :uri => uri,
        :headers => [{"Host", uri.host}],
        :payload => payload
    }
    {:ok, req} =  Signature.V4.sign(req, configs.region, endpoint_prefix)
    {:ok, status, resp_headers, ref} = :hackney.request(method(req.method),
                                                        to_string(req.uri),
                                                        req.headers, req.payload, [])
    {:ok, body} = :hackney.body(ref)
    
    {:ok, Aws.Output.RestXml.decode(spec.output.__struct__, body, resp_headers)}
  end

  def request("query", endpoint_prefix, api_version, signature_version, args, spec) do
    configs = Aws.Config.get()
    endpoint = Aws.Endpoints.get(configs.region, endpoint_prefix)
    uri = URI.parse(endpoint.uri)
    uri = %{uri | :path => spec.http.requestUri |> render_uri_template(args)}

    params = %{"Action" => spec.name,
               "Version" => api_version}
    
    req = %Request
    {
        :method => spec.http.method,
        :uri => uri,
        :headers => [{"Host", uri.host},
                     {"Content-type", "application/x-www-form-urlencoded; charset=utf-8"}],
        :payload => URI.encode_query(params)
    }
    {:ok, req} = Signature.V4.sign(req, configs.region, endpoint_prefix)
    {:ok, status, resp_headers, ref} = :hackney.request(method(req.method),
                                                        to_string(req.uri),
                                                        req.headers, req.payload, [])
    {:ok, body} = :hackney.body(ref)
    
    body
  end
  
  def request(_, _, _, _, _, _) do
    {:error, :protocol_not_implemented}
  end
  
  def render_uri_template(template, args) do
    Regex.scan(~r/{(.*?)}/, template)
    |> Enum.reduce(template,
      fn [_, part], template ->
        re = Regex.escape("{#{part}}")
        |> Regex.compile!
        
        if String.ends_with?(part, "+") do
          {argname, _} = String.split_at(part, -1)
          safe = &unescaped?(&1)
        else
          argname = part
          safe = &URI.char_unreserved?(&1)
        end

        argname = String.to_atom(argname)
        
        Regex.replace(re, template, URI.encode(args[argname], safe))
      end)
  end
  
  defp unescaped?(chr) do
    URI.char_unreserved?(chr) or chr in '/~'
  end

  defp method("GET"), do: :get
  defp method("POST"), do: :post
  defp method("PUT"), do: :put
  defp method("DELETE"), do: :delete
  defp method("HEAD"), do: :head
  
end
