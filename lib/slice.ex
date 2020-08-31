defmodule Prismic.Slice do
  defstruct items: [], primary: %{}, type: nil

  def build(slices) when is_list(slices), do: for(s <- slices, do: build(s))

  def build(%{"items" => items, "primary" => primary, "slice_type" => type}) do
    %__MODULE__{items: items, primary: primary, type: type}
  end
end
