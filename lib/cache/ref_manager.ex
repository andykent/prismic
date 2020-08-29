defmodule Prismic.Cache.RefManager do
  use GenServer

  require Logger

  def start_link(opts) do
    repo = Keyword.fetch!(opts, :repo)
    refs = Keyword.fetch!(opts, :refs)
    registry = Keyword.fetch!(opts, :registry)
    ref_cache_sup = Keyword.fetch!(opts, :ref_cache_sup)
    store = Keyword.fetch!(opts, :store)

    GenServer.start_link(__MODULE__, %{
      repo: repo,
      refs: refs,
      registry: registry,
      ref_cache_sup: ref_cache_sup,
      store: store
    })
  end

  @impl GenServer
  def init(%{
        repo: repo,
        refs: refs,
        registry: registry,
        ref_cache_sup: ref_cache_sup,
        store: store
      }) do
    {:ok,
     %{
       repo: repo,
       refs: refs,
       registry: registry,
       ref_cache_sup: ref_cache_sup,
       store: store
     }, {:continue, :start_ref_caches}}
  end

  @impl true
  def handle_continue(:start_ref_caches, state) do
    %{repo: repo, refs: refs, registry: registry, ref_cache_sup: ref_cache_sup, store: store} =
      state

    for ref <- refs do
      name = {:via, Registry, {registry, ref}}
      child = {Prismic.Cache.RefCache, name: name, repo: repo, ref: ref, store: store}
      DynamicSupervisor.start_child(ref_cache_sup, child)
    end

    {:noreply, state}
  end
end
