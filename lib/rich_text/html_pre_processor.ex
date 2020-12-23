defmodule Prismic.RichText.HTMLPreProcessor do
  # @callback block_tag(Prismic.RichText.Block.t()) :: {binary(), keyword()}
  @callback span_tag(map()) :: {binary(), keyword()}
end

defmodule Prismic.RichText.HTMLPreProcessor.Default do
  @behaviour Prismic.RichText.HTMLPreProcessor

  def span_tag(%{"type" => "hyperlink", "data" => %{"link_type" => "Web", "url" => href}}) do
    {"a", [href: href]}
  end

  def span_tag(%{"type" => type}), do: {type, []}
end
