defmodule Prismic.Repo do
  alias Prismic.Repo.Support
  alias Prismic.Cache.{Store, Hydrator}

  # defmacro __using__(args \\ []) do
  #   content_types = Keyword.get(args, :content_types, [])

  #   loaders =
  #     for {type, mod} <- content_types do
  #       quote do
  #         def fetch(client, unquote(mod)), do: Support.fetch(client, unquote(type), unquote(mod))
  #       end
  #     end

  #   quote do
  #     defdelegate client(ref \\ "master"), to: Prismic.API

  #     def content_types, do: unquote(content_types)
  #     def fetch_all(client), do: Support.fetch_all(client, content_types())

  #     unquote(loaders)
  #   end
  # end

  defmacro __using__(args \\ []) do
    cache = Keyword.get(args, :cache, nil)

    quote do
      def cache, do: unquote(cache)

      def get(type, opts \\ []) do
        case revision_for_opts(opts) do
          {:ok, revision} -> Store.fetch(cache(), revision, type)
          err -> err
        end
      end

      def get!(type, opts \\ []), do: Support.return_or_raise(get(type, opts))

      def get_by_id(type, id, opts \\ []) do
        case revision_for_opts(opts) do
          {:ok, revision} -> Store.fetch(cache(), revision, type, id)
          err -> err
        end
      end

      def get_by_id!(type, id, opts \\ []), do: Support.return_or_raise(get_by_id(type, id, opts))

      def get_by_index(type, index, value, opts \\ []) do
        case revision_for_opts(opts) do
          {:ok, revision} -> Store.fetch(cache(), revision, type, {index, value})
          err -> err
        end
      end

      def get_by_index!(type, index, value, opts \\ []),
        do: Support.return_or_raise(get_by_index(type, index, value, opts))

      def all(type, opts \\ []) do
        case revision_for_opts(opts) do
          {:ok, revision} -> Store.fetch_all(cache(), revision, type)
          err -> err
        end
      end

      def all!(type, opts \\ []), do: Support.return_or_raise(all(type, opts))

      def hydrate(data), do: Hydrator.hydrate(cache(), data)
      def hydrate_once(data), do: Hydrator.hydrate_once(cache(), data)

      defp revision_for_opts(opts) do
        ref = Keyword.get(opts, :ref, "master")
        Store.current_revision(cache(), ref)
      end

      def client_config, do: Application.fetch_env!(:prismic, __MODULE__)

      defoverridable(client_config: 0)

      def client(ref \\ "master"), do: Prismic.API.client(client_config(), ref)

      def fetch_all(client), do: Support.fetch_all(client, content_types())
      def fetch_by_type(client, type), do: Support.fetch_by_type(client, content_types(), type)

      def link(link_data, revision) do
        Prismic.Link.build(link_data, revision, for({type, _} <- content_types(), do: type))
      end

      def image(nil), do: nil
      def image(image_data), do: Prismic.Image.build(image_data)
    end
  end
end
