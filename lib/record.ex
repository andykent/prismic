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

defimpl Prismic.Record, for: Any do
  # Implementations live in the applications that define the content structs,
  # so this fallback only ever runs for a struct that forgot to `defimpl`.
  def identity(value), do: no_impl!(value)
  def indexes(value), do: no_impl!(value)
  def redirects(value), do: no_impl!(value)
  def content_type(value), do: no_impl!(value)

  defp no_impl!(value) do
    raise Protocol.UndefinedError,
      protocol: Prismic.Record,
      value: value,
      description: "Prismic.Record must be implemented for this type before it can be cached"
  end
end
