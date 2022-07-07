defmodule Prismic.RichText.HTMLPreProcessor do
  # @callback block_tag(Prismic.RichText.Block.t()) :: {binary(), keyword()}
  @callback span_tag(map(), function()) :: {binary(), keyword()}
end

defmodule Prismic.RichText.HTMLPreProcessor.Default do
  @behaviour Prismic.RichText.HTMLPreProcessor

  def span_tag(%{"type" => "hyperlink", "data" => %{"link_type" => "Web", "url" => href}}, _) do
    {"a", [href: href]}
  end

  def span_tag(%{"type" => "hyperlink"}, nil), do: {"span", []}

  def span_tag(%{"type" => "hyperlink", "data" => data}, resolver) do
    case resolver.(data) do
      nil -> {"span", []}
      href when is_binary(href) -> {"a", [href: href]}
      attrs when is_list(attrs) -> {"a", attrs}
    end
  end

  def span_tag(%{"type" => type}, _), do: {type, []}
end
