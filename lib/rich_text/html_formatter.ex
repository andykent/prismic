defmodule Prismic.RichText.HTMLFormatter do
  alias Prismic.RichText
  alias RichText.HTMLPreProcessor
  alias Phoenix.HTML

  def render(%RichText{blocks: blocks, link_resolver: link_resolver}) do
    blocks
    |> Enum.map(fn block -> block_to_tag(block, link_resolver) end)
    |> Enum.chunk_by(fn {tag, _a, _c} -> tag end)
    |> Enum.map(&wrap_nested/1)
    |> Enum.map(&render/1)
    |> Enum.map(fn
      {:safe, content} -> content
      content -> content
    end)
  end

  def render({:img, attrs, url}) do
    {:safe, img} = HTML.Tag.img_tag(url, attrs)
    img
  end

  def render({tag, attrs, content}) when is_atom(tag) do
    {:safe, content} = HTML.Tag.content_tag(tag, {:safe, render(content)}, attrs)
    content
  end

  def render({:content, content}), do: content
  def render(content) when is_list(content), do: Enum.map(content, &render/1)
  def render({:safe, content}), do: content
  def render(content), do: content

  defp wrap_nested([]) do
    []
  end

  defp wrap_nested([tag]) do
    tag
  end

  defp wrap_nested([{tag, _, _} | _] = tags) do
    case tag do
      :ul_li -> {:ul, [], for(t <- tags, do: as_li(t))}
      :ol_li -> {:ol, [], for(t <- tags, do: as_li(t))}
      _ -> tags
    end
  end

  defp as_li({_, attr, content}), do: {:li, attr, content}

  defp block_to_tag(%RichText.Block{type: "image", url: url, alt: alt}, _) do
    {:img, [alt: alt], url}
  end

  defp block_to_tag(%RichText.Block{type: type, text: text, spans: spans}, link_resolver) do
    content = add_spans(text, spans || [], link_resolver)
    to_tag(type, [], {:content, content})
  end

  defp to_tag("heading1", attrs, content), do: {:h1, attrs, content}
  defp to_tag("heading2", attrs, content), do: {:h2, attrs, content}
  defp to_tag("heading3", attrs, content), do: {:h3, attrs, content}
  defp to_tag("heading4", attrs, content), do: {:h4, attrs, content}
  defp to_tag("heading5", attrs, content), do: {:h5, attrs, content}
  defp to_tag("heading6", attrs, content), do: {:h6, attrs, content}
  defp to_tag("paragraph", attrs, content), do: {:p, attrs, content}
  defp to_tag("list-item", attrs, content), do: {:ul_li, attrs, content}
  defp to_tag("o-list-item", attrs, content), do: {:ol_li, attrs, content}
  defp to_tag(_, _attrs, content), do: content

  def add_spans(text, spans, link_resolver) do
    char_count = text |> String.graphemes() |> length()

    for {c, i} <- text |> String.graphemes() |> Enum.with_index() do
      start_spans =
        spans
        |> Enum.filter(fn %{"start" => s} -> s == i end)
        |> Enum.map(fn node -> open_span(node, link_resolver) end)

      end_spans =
        spans
        |> Enum.filter(fn %{"end" => e} -> e == i end)
        |> Enum.map(fn node -> close_span(node, link_resolver) end)

      final_end_spans =
        if i == char_count - 1 do
          spans
          |> Enum.filter(fn %{"end" => e} -> e == char_count end)
          |> Enum.map(fn node -> close_span(node, link_resolver) end)
        else
          []
        end

      case {start_spans, end_spans, final_end_spans} do
        {[], [], []} -> [c]
        {start_spans, [], []} -> [start_spans, c]
        {start_spans, [], final_end_spans} -> [start_spans, c, final_end_spans]
        {[], end_spans, []} -> [end_spans, c]
        {[], end_spans, final_end_spans} -> [end_spans, c, final_end_spans]
        {start_spans, end_spans, []} -> [end_spans, start_spans, c]
        {start_spans, end_spans, final_end_spans} -> [end_spans, start_spans, c, final_end_spans]
      end
    end
  end

  defp open_tag(tag, attrs), do: [?<, tag, tag_attrs(attrs), ?>]
  defp close_tag(tag), do: [?<, ?/, tag, ?>]

  defp open_span(span, link_resolver) do
    {tag, attrs} = HTMLPreProcessor.Default.span_tag(span, link_resolver)
    open_tag(tag, attrs)
  end

  defp close_span(span, link_resolver) do
    {tag, _attrs} = HTMLPreProcessor.Default.span_tag(span, link_resolver)
    close_tag(tag)
  end

  defp tag_attrs([]), do: []

  defp tag_attrs(attrs) do
    for a <- attrs do
      case a do
        {k, v} -> [?\s, to_string(k), ?=, ?", attr_escape(v), ?"]
        k -> [?\s, to_string(k)]
      end
    end
  end

  defp attr_escape({:safe, data}), do: data
  defp attr_escape(nil), do: []
  defp attr_escape(other) when is_binary(other), do: Plug.HTML.html_escape_to_iodata(other)
  defp attr_escape(other), do: HTML.Safe.to_iodata(other)
end
