defmodule Aws.Output.RestXml do

  def decode(shape, data) when is_binary(data) do
    decode(shape, parse_xml(data))
  end

  def decode(%{:members => members} = _shape, xml) do
    Enum.into(members, [], &decode(&1, xml))
  end
  
  def decode({name, %{:shape => shape}}, xml) do
    decode(name, shape.__struct__, xml)
  end
  
  def decode(name, %{:type => :structure} = shape, xml) do
    {name, Enum.into(shape.members, [], &decode(&1, xml))}
  end
  
  def decode(name, %{:type => :list} = shape, xml) do
    xpath = "//" <> to_string(name)
    [{:xmlElement, ^name, _, _, _, _, _, content, _, _, _, _}] =
      :xmerl_xpath.string(String.to_char_list(xpath), xml)
    {name, content}
  end
  
  def decode(name, %{:type => :string} = shape, xml) do
    xpath = "//" <> to_string(name) <> "/text()[1]"
    [{:xmlText, _parents, _pos, _lang, value, _type}] =
      :xmerl_xpath.string(String.to_char_list(xpath), xml)
    {name, to_string(value)}
  end
  
  def decode(name, shape, data) do
    :error
  end
  
  defp parse_xml(data) do
    {root, []} = :xmerl_scan.string(String.to_char_list(data))
    root
  end
  
end
