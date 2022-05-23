defprotocol Prismic.Record do
  @fallback_to_any true
  @moduledoc """
  A small protocol for assigning identies to Structs. Example...

      "my-scene" = Record.identity(%Scene{id: "my-scene"})
  """
  @spec identity(t) :: any()
  def identity(value)

  @spec indexes(t) :: keyword()
  def indexes(value)

  @spec redirects(t) :: keyword()
  def redirects(value)

  @spec content_type(t) :: atom()
  def content_type(value)
end
