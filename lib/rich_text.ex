# %{"spans" => [%{"end" => 13, "start" => 0, "type" => "strong"}, %{"end" => 183, "start" => 157, "type" => "strong"}], "text" => "Sundeep Saini is a London Based Choreographer and movement director. Sundeep Saini is a London Based Choreographer and movement director. Sundeep Saini is a London Based Choreographer and movement director. Sundeep Saini is a London Based Choreographer and movement director.", "type" => "paragraph"}
defmodule Prismic.RichText.Block do
  defstruct text: "", type: "paragraph", spans: []
end

defmodule Prismic.RichText do
  alias Prismic.RichText.Block

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

  def to_html(%__MODULE__{blocks: blocks}) do
    blocks
    |> Enum.map(fn %Block{text: text, spans: spans} ->
      ["<p>", add_spans(text, spans), "</p>"]
    end)
  end

  def add_spans(text, spans) do
    for {c, i} <- text |> String.graphemes() |> Enum.with_index() do
      start_spans =
        spans
        |> Enum.filter(fn %{"start" => s} -> s == i end)
        |> Enum.map(fn %{"type" => type} -> ["<", type, ">"] end)

      end_spans =
        spans
        |> Enum.filter(fn %{"end" => e} -> e == i end)
        |> Enum.map(fn %{"type" => type} -> ["</", type, ">"] end)

      case {start_spans, end_spans} do
        {[], []} -> [c]
        {start_spans, []} -> [start_spans, c]
        {[], end_spans} -> [end_spans, c]
        {start_spans, end_spans} -> [end_spans, start_spans, c]
      end
    end
  end

  defimpl Phoenix.HTML.Safe do
    def to_iodata(rich_text) do
      Prismic.RichText.to_html(rich_text)
    end
  end
end
