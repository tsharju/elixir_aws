defmodule Aws.Services do
  
  compile_services = Application.get_env(:elixir_aws, :compile_services, [])
  |> Enum.into(HashSet.new)
  
  spec_path = Application.app_dir(:elixir_aws, "priv/aws")
  spec_dirs = File.ls!(spec_path)
  |> Enum.filter(fn name -> not String.contains?(name, ".json") end)
  |> Enum.into(HashSet.new)

  if HashSet.size(compile_services) > 0 do
    spec_dirs = HashSet.intersection(spec_dirs, compile_services)
  end
  
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

        @external_resource mod_spec_path = Path.join(mod_spec_path, mod_spec_file)
        
        spec = File.read!(mod_spec_path)
        |> Poison.decode!(keys: :atoms)
        
        service_name = spec.metadata.serviceFullName
        api_version = spec.metadata.apiVersion
        endpoint_prefix = spec.metadata.endpointPrefix
        protocol = spec.metadata.protocol
        signature_version = spec.metadata.signatureVersion

        @moduledoc "#{service_name}\n\nAPI version: #{api_version}"
        
        # declare module functions according to the loaded spec
        Enum.each(spec.operations,
          fn {operation_name, operation_spec} ->
            fun_name = Mix.Utils.underscore(to_string(operation_name))
            |> String.to_atom
            
            args = []
            
            if operation_spec[:input] != nil do
              if operation_spec.input[:shape] != nil do
                input_shape = spec.shapes[String.to_atom(operation_spec.input.shape)]
                if input_shape[:required] != nil do
                  args = Enum.map(input_shape.required, &String.to_atom(&1))
                  |> Enum.map(&Macro.var(&1, nil))
                end
              end
            end

            if operation_spec[:output] != nil do
              if operation_spec.output[:shape] != nil do
              end
            end
            
            if operation_spec[:documentation] do
              @doc operation_spec.documentation
              |> Aws.Utils.strip_html_tags
            end

            module_name = Aws.Services.S3.Shapes.ListBucketsOutput
            
            def unquote(fun_name)(unquote_splicing(args)) do
              args = binding()
              
              protocol = unquote(protocol)
              endpoint_prefix = unquote(endpoint_prefix)
              api_version = unquote(api_version)
              signature_version = unquote(signature_version)
              op_spec = unquote(Macro.escape(operation_spec))
              |> put_in([:output], %unquote(module_name){})
              Aws.Http.request(protocol, endpoint_prefix, api_version,
                               signature_version, args, op_spec)
            end
          end)
        end
    end)
  
end
