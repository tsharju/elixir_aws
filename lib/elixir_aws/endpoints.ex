defmodule Aws.Endpoints do

  @external_resource spec_path = Application.app_dir(:elixir_aws, "priv/aws/_endpoints.json")
  
  spec = File.read!(spec_path)
  |> Poison.decode!
  
  Enum.each(spec,
    fn {service, _endpoint} ->
      endpoint_spec = spec[service]
      
      def get(region, unquote(String.to_atom(service))) do
        endpoint_spec = unquote(Macro.escape(endpoint_spec))
        pick_endpoint(region, endpoint_spec)
      end
    end)
  
  def get(region, _) do
    get(region, :'_default')
  end

  defp pick_endpoint(region, endpoints) do
    # check constraints for endpoint
    endpoints = Enum.filter(endpoints,
      fn endpoint ->
        constraints = endpoint["constraints"]
        if constraints != nil do
          Enum.map(constraints, fn [_, c, v] -> [region, c, v] end)
          |> Enum.any?(&check_constraint(&1))
        else
          true
        end
      end)
    List.first(endpoints)
  end
  
  defp check_constraint([region, "startsWith", string]) do
    String.starts_with?(region, string)
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
