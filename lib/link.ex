defmodule Prismic.Link do
  defstruct id: nil, type: nil, is_broken: false, revision: nil

  def build(%{"id" => id, "type" => type_str, "isBroken" => is_broken}, revision, content_types) do
    %__MODULE__{
      id: id,
      type: to_content_type(type_str, content_types),
      is_broken: is_broken,
      revision: revision
    }
  end

  def build(_link, revision, content_types) do
    nil
  end

  defp to_content_type(type_str, content_types) do
    type = String.to_existing_atom(type_str)
    unless type in content_types, do: raise(ArgumentError, "unknown")
    type
  rescue
    _ -> raise ArgumentError, "unknown content type: #{type_str}"
  end
end
