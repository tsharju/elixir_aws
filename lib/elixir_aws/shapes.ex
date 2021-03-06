defmodule Aws.Shapes.Macros do

  defmacro shape_string(service, shape_spec) do
    quote do
      service = unquote(service)
      shape_spec = unquote(shape_spec)
      
      sensitive = Map.get(shape_spec, :sensitive, false)
      enum = Map.get(shape_spec, :enum, nil)
      
      [type: :string, sensitive: sensitive, enum: enum]
    end
  end
  
  defmacro shape_struct(service, shape_spec) do    
    quote do
      service = unquote(service)
      shape_spec = unquote(shape_spec)
      
      keys = Map.keys(shape_spec) |> Enum.into(HashSet.new)
      default_keys = [:type, :members, :required] |> Enum.into(HashSet.new)
      
      members = shape_spec[:members]
      |> Enum.into(
        [],
        fn {k, v} ->
          if Map.has_key?(v, :shape) do
            shape = Map.get(v, :shape)
            |> String.to_atom
            mod = Module.concat([:'Aws', :'Services', service, :'Shapes', shape])
            v = put_in(v, [:shape], mod)
          end
          {k, v}
        end)
      required = Map.get(shape_spec, :required, [])
      |> Enum.map(&String.to_atom(&1))

      # add optionals
      opts = HashSet.difference(keys, default_keys)
      |> Enum.map(fn key -> {key, Map.get(shape_spec, key)} end)
      
      [type: :structure, members: members, required: required, opts: opts]
    end
  end

  defmacro shape_list(service, shape_spec) do
    quote do
      service = unquote(service)
      shape_spec = unquote(shape_spec)

      member_spec = Map.get(shape_spec, :member)
      member_shape = Map.get(member_spec, :shape)
      |> String.to_atom
      member_mod = Module.concat([:'Aws', :'Services', service, :'Shapes', member_shape])
      member = put_in(member_spec, [:shape], member_mod)
      |> put_in([:name], member_shape)

      flattened = Map.get(member_spec, :flattened, false)
      
      [type: :list, member: member, flattened: flattened]
    end
  end

  defmacro shape_map(service, shape_spec) do
    quote do
      service = unquote(service)
      shape_spec = unquote(shape_spec)

      key_shape = get_in(shape_spec, [:key, :shape])
      key_mod = Module.concat([:'Aws', :'Services', service, :'Shapes', key_shape])

      value_shape = get_in(shape_spec, [:value, :shape])
      value_mod = Module.concat([:'Aws', :'Services', service, :'Shapes', value_shape])

      [type: :map, key: key_mod, value: value_mod]
    end
  end
  
  defmacro shape_timestamp(service, shape_spec) do
    quote do
      service = unquote(service)
      shape_spec = unquote(shape_spec)

      format = Map.get(shape_spec, :'timestampFormat', nil)

      [type: :timestamp, 'timestampFormat': format]
    end
  end

  defmacro shape_bool(service, shape_spec) do
    quote do
      service = unquote(service)
      shape_spec = unquote(shape_spec)

      [type: :boolean]
    end
  end

  defmacro shape_integer(service, shape_spec) do
    quote do
      service = unquote(service)
      shape_spec = unquote(shape_spec)

      [type: :integer]
    end
  end
  
end

defmodule Aws.Shapes do

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
          if Map.has_key?(shape_spec, :type) do
            defmodule Module.concat([:'Aws', :'Services', service_name,
                                     :'Shapes', shape_name]) do
              require Aws.Shapes.Macros

              case shape_spec.type do
                "structure" ->
                  defstruct Aws.Shapes.Macros.shape_struct(service_name, shape_spec)
                "map" ->
                  defstruct Aws.Shapes.Macros.shape_map(service_name, shape_spec)
                "list" ->
                  defstruct Aws.Shapes.Macros.shape_list(service_name, shape_spec)
                "string" ->
                  defstruct Aws.Shapes.Macros.shape_string(service_name, shape_spec)
                "timestamp" ->
                  defstruct Aws.Shapes.Macros.shape_timestamp(service_name, shape_spec)
                "boolean" ->
                  defstruct Aws.Shapes.Macros.shape_bool(service_name, shape_spec)
                "integer" ->
                  defstruct Aws.Shapes.Macros.shape_integer(service_name, shape_spec)
                "long" ->
                  defstruct Aws.Shapes.Macros.shape_integer(service_name, shape_spec)
                type ->
                  IO.puts "Warning: ignoring unknown shape type: #{type}"
              end
            end
          end
        end)
    end)
  
end
