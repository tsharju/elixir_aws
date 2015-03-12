defmodule Aws.Utils do
  
  def strip_html_tags(nil), do: nil
  def strip_html_tags(string) do
    Regex.replace(~r/<(.)*?>/, string, "")
  end
  
end
