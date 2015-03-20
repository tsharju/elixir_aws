defmodule Aws.Shapes do

  compile_services = Application.get_env(:elixir_aws, :compile_services, [])
  |> Enum.into(HashSet.new)
  
  spec_path = Application.app_dir(:elixir_aws, "priv/aws")
  spec_dirs = File.ls!(spec_path)
  |> Enum.filter(fn name -> not String.contains?(name, ".json") end)
  |> Enum.into(HashSet.new)
  
  if compile_services != [] do
    spec_dirs = HashSet.intersection(compile_services, spec_dirs)
  end
  
  Enum.each(spec_dirs,
    fn dir_name ->
      service_name = Mix.Utils.camelize(dir_name)
      |> String.to_atom
      
      mod_spec_path = Path.join(spec_path, dir_name)
      mod_spec_files = File.ls!(mod_spec_path)
      
      mod_spec_file = Enum.filter(mod_spec_files,
        fn name -> String.contains?(name, "normal.json") end)
      |> Enum.sort
      |> List.first
      
      @external_resource mod_spec_path = Path.join(mod_spec_path, mod_spec_file)
      
      spec = File.read!(mod_spec_path)
      |> Poison.decode!(keys: :atoms)
      
      # declare module shapes
      Enum.each(spec.shapes,
        fn {shape_name, shape_spec} ->
          defmodule Module.concat([:'Aws', :'Services', service_name,
                                   :'Shapes', shape_name]) do
            defstruct Enum.into(shape_spec, [], fn kv -> kv end)
          end
        end)
      
    end)
  
end
