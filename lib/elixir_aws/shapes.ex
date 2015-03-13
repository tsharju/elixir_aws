defmodule Aws.Shape do

  def expand(shape, shapes) do
    shape = shapes[shape]
    members = shape[:members]
    |> Enum.map(
      fn {name, member} ->
        shape = shapes[String.to_atom(member.shape)]
        {name, %{member | :shape => shape}}
      end)
    %{shape | :members => members}
  end
  
end
