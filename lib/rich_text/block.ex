defmodule Prismic.RichText.Block do
  defstruct text: "", type: "paragraph", spans: []
  @type t :: %__MODULE__{}
end
