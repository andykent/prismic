defmodule Prismic.API do
  @type client_with_ref :: {any(), binary()}
  @callback fetch_repository(any()) :: {:ok, map()} | {:error, any()}
  @callback client(keyword(), binary()) :: client_with_ref()
  @callback list_by_type(client_with_ref(), binary()) :: list()

  def fetch_repository(config) do
    adapter().fetch_repository(config)
  end

  def client(config, ref_id \\ "master") do
    adapter().client(config, ref_id)
  end

  def list_by_type(client, type) do
    adapter().list_by_type(client, type)
  end

  def ref({_client, ref}), do: ref

  defp adapter do
    Application.get_env(:prismic, __MODULE__, Prismic.API.HTTP)
  end
end
