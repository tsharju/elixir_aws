defmodule Aws.Http do
  
  defmodule Request do
    defstruct method: nil, uri: nil, headers: [], payload: nil, query: ""
    @type t :: %Request{method: binary, uri: binary, headers: List.t, payload: binary, query: binary}
  end
  
  def request(protocol, endpoint_prefix, api_version, signature_version, args, spec) do
    
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
  
end
