defmodule Aws.Output.RestXml do

  def decode(%{:type => :structure} = shape, data) do
    binding()
  end
  
  def decode(shape, data) do
    :error
  end
  
  defp parse_xml(data) do
  end
  
end
