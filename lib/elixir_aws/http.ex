defmodule Aws.Http do

  alias Aws.Auth.Signature
  
  defmodule Request do
    defstruct method: nil, uri: %URI{}, headers: [], payload: "", query: ""
    @type t :: %Request{method: binary, uri: URI.t, headers: List.t, payload: binary, query: binary}
  end
  
  def request("rest-xml", endpoint_prefix, api_version, signature_version, args, spec) do
    IO.inspect binding()
    
    configs = Aws.Config.get()
    endpoint = Aws.Endpoints.get(configs.region, endpoint_prefix)
    uri = URI.parse(endpoint.uri)
    uri = %{uri | :path => spec.http.requestUri |> render_uri_template(args)}
    
    req = %Request
    {
        :method => spec.http.method,
        :uri => uri,
        :headers => [{"Host", uri.host}]
    }
    {:ok, req} =  Signature.V4.sign(req, configs.region, endpoint_prefix)
    
    {:ok, status, _, ref} = :hackney.request(method(req.method), to_string(req.uri), req.headers, "", [])
    :hackney.body(ref)
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
