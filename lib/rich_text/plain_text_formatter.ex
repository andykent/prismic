defmodule Prismic.RichText.PlainTextFormatter do
  alias Prismic.RichText

  def render(%RichText{blocks: blocks}) do
    blocks
    |> Enum.map(&block_to_plain_text/1)
    |> Enum.join("\n\n")
  end

  defp block_to_plain_text(%Prismic.RichText.Block{text: text}), do: text

  defp block_to_plain_text(%Prismic.RichText.Block{type: "image", url: url, alt: alt}),
    do: "[#{alt}](#{url})"

  defp block_to_plain_text(%Prismic.RichText.Block{text: nil}), do: ""
end
