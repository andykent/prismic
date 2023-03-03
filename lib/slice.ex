defmodule Prismic.Slice do
  defstruct id: nil, items: [], primary: %{}, type: nil

  def build(slices) when is_list(slices), do: for(s <- slices, do: build(s))

  def build(%{"id" => id, "items" => items, "primary" => primary, "slice_type" => type}) do
    %__MODULE__{id: id, items: items, primary: primary, type: type}
  end
end
