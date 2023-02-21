defmodule Prismic.Cache do
  alias Prismic.Cache.{RefManager, Store}

  use Supervisor

  require Logger

  @default_refresh_rate 1 * 60 * 1000

  defmacro __using__(_args \\ []) do
    quote do
      def get() do
        __MODULE__
      end
    end
  end

  def start_link(opts) do
    repo = Keyword.fetch!(opts, :repo)
    refs = Keyword.fetch!(opts, :refs)
    name = Keyword.get(opts, :name, repo.cache())
    refresh_rate = Keyword.get(opts, :refresh_rate, @default_refresh_rate)
    registry = String.to_atom("#{name}.Registry")
    ref_cache_sup = String.to_atom("#{name}.RefCacheSupervisor")
    store = String.to_atom("#{name}.Store")

    args = %{
      repo: repo,
      refs: refs,
      registry: registry,
      ref_cache_sup: ref_cache_sup,
      store: store,
      table: repo.cache(),
      manager: name,
      refresh_rate: refresh_rate
    }

    Supervisor.start_link(__MODULE__, args)
  end

  @impl Supervisor
  def init(%{
        repo: repo,
        refs: refs,
        registry: registry,
        ref_cache_sup: ref_cache_sup,
        store: store,
        table: table,
        manager: name,
        refresh_rate: refresh_rate
      }) do
    children = [
      {Store, name: store, table: table},
      {Registry, keys: :unique, name: registry},
      {DynamicSupervisor, name: ref_cache_sup, strategy: :one_for_one},
      {RefManager,
       name: name,
       repo: repo,
       refs: refs,
       registry: registry,
       ref_cache_sup: ref_cache_sup,
       store: store,
       refresh_rate: refresh_rate}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
