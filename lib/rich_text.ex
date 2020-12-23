defmodule Prismic.RichText do
  alias Prismic.RichText.{Block, HTMLFormatter, PlainTextFormatter}

  defstruct blocks: []

  def build(nil), do: %__MODULE__{blocks: []}

  def build(block_data) do
    blocks =
      for block <- block_data do
        %Block{text: block["text"], spans: block["spans"], type: block["type"]}
      end

    %__MODULE__{
      blocks: blocks
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
