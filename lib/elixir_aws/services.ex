defmodule Aws.Services do
  
  @external_resource spec_path = Application.app_dir(:elixir_aws, "priv/aws")
  spec_dirs = File.ls!(spec_path)
  |> Enum.filter(fn name -> not String.contains?(name, ".json") end)
  
  Enum.each(spec_dirs,
    fn dir_name ->
      mod_name = Mix.Utils.camelize(dir_name)
      |> String.to_atom

      defmodule Module.concat(__MODULE__, mod_name) do

        mod_spec_path = Path.join(spec_path, dir_name)
        mod_spec_files = File.ls!(mod_spec_path)
        
        mod_spec_file = Enum.filter(mod_spec_files,
          fn name -> String.contains?(name, "normal.json") end)
        |> Enum.sort
        |> List.first
        
        spec = File.read!(Path.join(mod_spec_path, mod_spec_file))
        |> Poison.decode!
        
        service_name = spec["metadata"]["serviceFullName"]
        api_version = spec["metadata"]["apiVersion"]
        endpoint_prefix = spec["metadata"]["endpointPrefix"]
        protocol = spec["metadata"]["protocol"]

        @moduledoc ~s(#{service_name}\n\nAPI version: #{api_version})

        # declare module functions according to the loaded spec
        Enum.each(spec["operations"],
          fn {operation_name, operation_spec} ->
            fun_name = Mix.Utils.underscore(operation_name)
            |> String.to_atom
            
            args = []
            if operation_spec["input"] != nil do
              shape_name = operation_spec["input"]["shape"]
              shape = spec["shapes"][shape_name]
              if shape["required"] != nil do
                args = Enum.map(shape["required"], &Mix.Utils.underscore(&1))
                |> Enum.map(&String.to_atom(&1))
                |> Enum.map(&Macro.var(&1, nil))
              end
            end
            
            @doc operation_spec["documentation"]
            |> Aws.Utils.strip_html_tags
            def unquote(fun_name)(unquote_splicing(args)) do
              args = binding()
              op_spec = unquote(Macro.escape(operation_spec))
              unquote(protocol)
            end
          end)
        end
    end)
  
end
