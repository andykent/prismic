defmodule Prismic.API do
  @type client_with_ref :: {any(), binary()}
  @callback client(keyword(), binary()) :: client_with_ref()
  @callback list_by_type(client_with_ref(), binary()) :: list()

  @adapter Application.compile_env(:prismic, __MODULE__, Prismic.API.HTTP)

  defdelegate client(config, ref_id \\ "master"), to: @adapter
  defdelegate list_by_type(client, type), to: @adapter

  def ref({_client, ref}), do: ref
end
