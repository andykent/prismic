defmodule Prismic.RichText.Block do
  defstruct text: "",
            type: "paragraph",
            spans: [],
            alt: nil,
            copyright: nil,
            dimensions: nil,
            url: nil

  @type t :: %__MODULE__{}
end
