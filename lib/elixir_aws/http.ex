defmodule Aws.Http do

  def request(protocol, endpoint_prefix, args, spec, output) do
    
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
        
        argname = Mix.Utils.underscore(argname)
        |> String.to_atom
        
        Regex.replace(re, template, URI.encode(args[argname], safe))
      end)
  end
  
  defp unescaped?(chr) do
    URI.char_unreserved?(chr) or chr in '/~'
  end
  
end
