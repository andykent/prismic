defmodule Prismic.Cache.RefManager do
  @timeout 60 * 1000

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
    schedule_refresh(refresh_rate)

    {:ok,
     %{
       repo: repo,
       refs: refs,
       registry: registry,
       ref_cache_sup: ref_cache_sup,
       store: store,
       refresh_rate: refresh_rate,
       tracked_ref_pids: []
     }, {:continue, :start_missing_ref_caches}}
  end

  @impl true
  def handle_continue(:start_missing_ref_caches, state) do
    {:noreply, start_missing_ref_caches(state)}
  end

  defp fetch_refs(refs) when is_function(refs), do: refs.()
  defp fetch_refs(refs) when is_list(refs), do: refs
  defp fetch_refs(refs), do: [refs]

  def refresh_all(manager), do: GenServer.call(manager, :refresh_all, @timeout)

  def refresh(manager, ref), do: GenServer.call(manager, {:refresh, ref}, @timeout)

  def available_refs(manager), do: GenServer.call(manager, :available_refs, @timeout)

  @impl true
  def handle_call(:refresh_all, _from, state) do
    state = start_missing_ref_caches(state)
    for {_ref, pid} <- state.tracked_ref_pids, do: Prismic.Cache.RefCache.refresh!(pid, :blocking)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:refresh, ref}, _from, %{registry: registry} = state) do
    do_refresh(registry, ref)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:update_tracked_refs, _from, state) do
    {:reply, :ok, start_missing_ref_caches(state)}
  end

  @impl true
  def handle_call(:available_refs, _from, %{tracked_ref_pids: tracked_ref_pids} = state) do
    refs = for {ref, _pid} <- tracked_ref_pids, do: ref
    {:reply, refs, state}
  end

  defp start_missing_ref_caches(state) do
    %{
      repo: repo,
      refs: refs,
      registry: registry,
      ref_cache_sup: ref_cache_sup,
      store: store,
      refresh_rate: refresh_rate,
      tracked_ref_pids: tracked_ref_pids
    } = state

    resolved_refs = fetch_refs(refs)
    to_remove = Enum.filter(tracked_ref_pids, fn {ref, _pid} -> ref not in resolved_refs end)

    created =
      for ref <- resolved_refs do
        case Registry.lookup(registry, ref) do
          [{pid, _}] ->
            {ref, pid}

          _ ->
            name = {:via, Registry, {registry, ref}}

            child =
              {Prismic.Cache.RefCache,
               name: name, repo: repo, ref: ref, store: store, refresh_rate: refresh_rate}

            {:ok, child_pid} = DynamicSupervisor.start_child(ref_cache_sup, child)
            {ref, child_pid}
        end
      end

    for {ref, pid} <- to_remove do
      Logger.info("[Prismic.Cache] removing RefCache for '#{ref}' with pid #{inspect(pid)}")
      DynamicSupervisor.terminate_child(ref_cache_sup, pid)
    end

    tracked_ref_pids =
      (tracked_ref_pids ++ created) |> Enum.uniq() |> Enum.filter(fn v -> v not in to_remove end)

    Map.put(state, :tracked_ref_pids, tracked_ref_pids)
  end

  defp do_refresh(registry, ref) do
    case Registry.lookup(registry, ref) do
      [{pid, _}] -> Prismic.Cache.RefCache.refresh!(pid, :blocking)
      _ -> Logger.warning("[Prismic.Cache] Unable to refresh #{ref} due to missing process")
    end
  end

  @impl GenServer
  def handle_info(:refresh, %{refresh_rate: delay} = state) do
    schedule_refresh(delay)
    {:noreply, state, {:continue, :start_missing_ref_caches}}
  end

  defp schedule_refresh(ms) when is_integer(ms) do
    Logger.info("[Prismic.Cache] scheduling refresh in #{ms}")
    Process.send_after(self(), :refresh, ms)
  end

  defp schedule_refresh(_), do: nil
end
