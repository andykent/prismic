defmodule Prismic.RichText do
  alias Prismic.RichText.{Block, HTMLFormatter, PlainTextFormatter}

  defstruct blocks: [], link_resolver: nil

  def build(block_data, link_resolver \\ nil)

  def build(nil, link_resolver), do: %__MODULE__{blocks: [], link_resolver: link_resolver}

  def build(block_data, link_resolver) do
    blocks =
      for block <- block_data do
        %Block{
          text: block["text"],
          spans: block["spans"],
          type: block["type"],
          alt: block["alt"],
          copyright: block["copyright"],
          dimensions: block["dimensions"],
          url: block["url"]
        }
      end

    %__MODULE__{
      blocks: blocks,
      link_resolver: link_resolver
    }
  end

  def to_html(content), do: HTMLFormatter.render(content)

  defimpl String.Chars do
    def to_string(content), do: PlainTextFormatter.render(content)
  end

  defimpl Phoenix.HTML.Safe do
    def to_iodata(rich_text) do
      Prismic.RichText.to_html(rich_text)
    end
  end
end
