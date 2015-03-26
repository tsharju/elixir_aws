defmodule Aws.Output.RestXml do

  require Record
  
  Record.defrecord :xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  
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
  
  def decode(name, %{:type => :list, :member => member} = shape, xml) do
    xpath = "//" <> to_string(name)
    case :xmerl_xpath.string(String.to_char_list(xpath), xml) do
      [element] ->
        content = xmlElement(element, :content)
        content = Enum.filter(content, &Record.is_record(&1, :xmlElement))
        |> Enum.map(&decode(member.name, member.shape.__struct__, &1))
        {name, content}
      [] ->
        {name, nil}
    end
  end
  
  def decode(name, %{:type => :string} = shape, xml) do
    xpath = "//" <> to_string(name) <> "/text()[1]"
    case :xmerl_xpath.string(String.to_char_list(xpath), xml) do
      [text] ->
        value = xmlText(text, :value)
        {name, to_string(value)}
      [] ->
        {name, nil}
    end
  end

  def decode(name, %{:type => :timestamp} = shape, xml) do
    # TODO: handle date formats
    xpath = "//" <> to_string(name) <> "/text()[1]"
    [text] = :xmerl_xpath.string(String.to_char_list(xpath), xml)
    value = xmlText(text, :value)
    {name, to_string(value)}
  end

  def decode(name, %{:type => :boolean} = shape, xml) do
    xpath = "//" <> to_string(name) <> "/text()[1]"
    [text] = :xmerl_xpath.string(String.to_char_list(xpath), xml)
    value = xmlText(text, :value)
    {name, value == 'true'}
  end

  def decode(name, %{:type => :integer} = shape, xml) do
    xpath = "//" <> to_string(name) <> "/text()[1]"
    [text] = :xmerl_xpath.string(String.to_char_list(xpath), xml)
    {value, ""} = xmlText(text, :value)
    |> to_string
    |> Integer.parse
    
    {name, value}
  end
  
  def decode(name, %{:type => type} = shape, xml) do
    {name, {:error, {:unknown_type, type}}}
  end
  
  defp parse_xml(data) do
    {root, []} = :xmerl_scan.string(String.to_char_list(data))
    root
  end

  defp elements([], _name, acc) do
    acc
  end
  
  defp elements([xmlElement(name: name) = elem|rest], name, acc) do
    elements(rest, name, [elem|acc])
  end
  
end
