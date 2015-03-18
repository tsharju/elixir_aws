defmodule Aws.Config do

  defmodule Configs do
    defstruct key: nil, secret: nil, region: nil
  end
  
  def get() do
    get(:env)
    |> get(:aws_cli)
  end

  defp get(:env) do
    %Configs{:key => System.get_env("AWS_ACCESS_KEY_ID"),
             :secret => System.get_env("AWS_SECRET_ACCESS_KEY"),
             :region => System.get_env("AWS_DEFAULT_REGION")}
  end
  
  defp get(configs, _) when configs != %Configs{} do
    configs
  end
  
  defp get(configs, :aws_cli) do
    aws_configs = %Configs{}
    home = System.get_env("HOME")
    case File.read(Path.join(home, "/.aws/credentials")) do
      {:ok, credentials_ini} ->
        credentials = parse_ini_file(credentials_ini)
        aws_configs = Map.put(aws_configs, :key, credentials[:aws_access_key_id])
        |> Map.put(:secret, credentials[:aws_secret_access_key])
        case File.read(Path.join(home, "/.aws/config")) do
          {:ok, config_ini} ->
            config = parse_ini_file(config_ini)
            aws_configs = Map.put(aws_configs, :region, config[:region])
          _ ->
        end
      _ ->
    end
    aws_configs
  end
  
  defp parse_ini_file(data) do
    String.split(data, "\n")
    |> Enum.filter(&String.contains?(&1, "="))
    |> Enum.map(
      fn string ->
        [key, value] = String.split(string, "=")
        key = String.strip(key)
        |> String.to_atom
        {key, String.strip(value)}
      end)
  end
  
end
