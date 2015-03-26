defmodule Aws.Endpoints do

  @external_resource spec_path = Application.app_dir(:elixir_aws, "priv/aws/_endpoints.json")
  
  spec = File.read!(spec_path)
  |> Poison.decode!(keys: :atoms)

  default_endpoint_spec = spec[:'_default']
  
  Enum.each(spec,
    fn {service, _endpoint} ->
      endpoint_spec = spec[service]
      
      def get(region, unquote(service)) do
        endpoint_spec = unquote(Macro.escape(endpoint_spec))
        pick_endpoint(region, unquote(service), endpoint_spec)
      end
    end)
  
  def get(region, service) when is_binary(service) do
    get(region, String.to_atom(service))
  end
  
  def get(region, service) do
    endpoint_spec = unquote(Macro.escape(default_endpoint_spec))
    pick_endpoint(region, service, endpoint_spec)
  end
    
  defp pick_endpoint(region, endpoint_prefix, endpoints) do
    # check constraints for endpoint
    endpoints = Enum.filter(endpoints,
      fn endpoint ->
        constraints = endpoint[:constraints]
        if constraints != nil do
          Enum.map(constraints, fn [_, c, v] -> [region, c, v] end)
          |> Enum.any?(&check_constraint(&1))
        else
          true
        end
      end)
    endpoint = List.first(endpoints)
    uri = Enum.reduce(
      [scheme: "https", service: to_string(endpoint_prefix), region: region], endpoint.uri,
      fn {key, value}, uri_template ->
        Regex.compile!("{#{key}}")
        |> Regex.replace(uri_template, value)
      end)
    %{endpoint | :uri => uri}
  end
  
  defp check_constraint([region, "startsWith", string]) do
    String.starts_with?(region, string)
  end
  
  defp check_constraint([region, "notStartsWith", string]) do
    not String.starts_with?(region, string)
  end
  
  defp check_constraint([region, "equals", value]) do
    region == value
  end
  
  defp check_constraint([region, "notEquals", value]) do
    region != value
  end
  
  defp check_constraint([region, "oneOf", list]) do
    region in list
  end
  
end
