defmodule Prismic.ContentType do
  @callback from_prismic(map(), String.t()) :: struct()
end
