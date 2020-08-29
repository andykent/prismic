defprotocol Prismic.Record do
  @moduledoc """
  A small protocol for assigning identies to Structs. Example...

      "my-scene" = Record.identity(%Scene{id: "my-scene"})
  """
  @spec identity(t) :: any()
  def identity(value)

  @spec indexes(t) :: keyword()
  def indexes(value)

  @spec content_type(t) :: atom()
  def content_type(value)
end
