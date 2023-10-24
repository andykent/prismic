defmodule Prismic.Cache.RefManager do
  use GenServer

  require Logger

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    repo = Keyword.fetch!(opts, :repo)
    refs = Keyword.fetch!(opts, :refs)
    registry = Keyword.fetch!(opts, :registry)
    ref_cache_sup = Keyword.fetch!(opts, :ref_cache_sup)
    store = Keyword.fetch!(opts, :store)
    refresh_rate = Keyword.fetch!(opts, :refresh_rate)

    GenServer.start_link(
      __MODULE__,
      %{
        repo: repo,
        refs: refs,
        registry: registry,
        ref_cache_sup: ref_cache_sup,
        store: store,
        refresh_rate: refresh_rate
      },
      name: name
    )
  end

  @impl GenServer
  def init(%{
        repo: repo,
        refs: refs,
        registry: registry,
        ref_cache_sup: ref_cache_sup,
        store: store,
        refresh_rate: refresh_rate
      }) do
    {:ok,
     %{
       repo: repo,
       refs: refs,
       registry: registry,
       ref_cache_sup: ref_cache_sup,
       store: store,
       refresh_rate: refresh_rate
     }, {:continue, :start_ref_caches}}
  end

  @impl true
  def handle_continue(:start_ref_caches, state) do
    %{
      repo: repo,
      refs: refs,
      registry: registry,
      ref_cache_sup: ref_cache_sup,
      store: store,
      refresh_rate: refresh_rate
    } = state

    for ref <- refs do
      name = {:via, Registry, {registry, ref}}

      child =
        {Prismic.Cache.RefCache,
         name: name, repo: repo, ref: ref, store: store, refresh_rate: refresh_rate}

      DynamicSupervisor.start_child(ref_cache_sup, child)
    end

    {:noreply, state}
  end

  def refresh_all(manager), do: GenServer.call(manager, :refresh_all)

  def refresh(manager, ref), do: GenServer.call(manager, {:refresh, ref})

  @impl true
  def handle_call(:refresh_all, _from, %{registry: registry, refs: refs} = state) do
    for ref <- refs, do: do_refresh(registry, ref)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:refresh, ref}, _from, %{registry: registry} = state) do
    do_refresh(registry, ref)
    {:reply, :ok, state}
  end

  defp do_refresh(registry, ref) do
    case Registry.lookup(registry, ref) do
      [{pid, _}] -> Prismic.Cache.RefCache.refresh!(pid)
      _ -> Logger.warning("Unable to refresh #{ref} due to missing process")
    end
  end
end
