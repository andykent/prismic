defmodule Prismic.Image do
  defstruct alt: nil, copyright: nil, dimensions: nil, url: nil

  def build(attrs) do
    dimensions = Map.get(attrs, "dimensions", %{})

    %__MODULE__{
      alt: attrs["alt"],
      copyright: attrs["copyright"],
      dimensions: %{width: dimensions["width"], height: dimensions["height"]},
      url: attrs["url"]
    }
  end

  def resize(%__MODULE__{} = img, width, height) do
    with_params(img, w: width, h: height)
  end

  def with_params(%__MODULE__{url: base_uri} = image, params) do
    uri = URI.parse(base_uri)

    modified_uri =
      uri
      |> Map.put(:query, modify_query(uri.query, params))
      |> URI.to_string()

    Map.put(image, :url, modified_uri)
  end

  defp modify_query(query_string, params) do
    query = query_string |> URI.query_decoder() |> Enum.to_list() |> Enum.reverse()

    params
    |> Enum.reduce(query, fn {k, v}, q -> Keyword.put(q, k, v) end)
    |> Enum.reverse()
    |> URI.encode_query()
  end
end
