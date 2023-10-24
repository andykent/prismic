defmodule Prismic.Cache.RefCache do
  use GenServer

  require Logger

  def refresh(cache) do
    GenServer.cast(cache, {:refresh, false})
  end

  @doc "Trigger a refresh and force pull changes regardless of if the ref has changed or not"
  def refresh!(cache) do
    GenServer.cast(cache, {:refresh, true})
  end

  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    repo = Keyword.fetch!(opts, :repo)
    ref = Keyword.fetch!(opts, :ref)
    store = Keyword.fetch!(opts, :store)
    refresh_rate = Keyword.fetch!(opts, :refresh_rate)

    GenServer.start_link(
      __MODULE__,
      %{repo: repo, ref: ref, store: store, refresh_rate: refresh_rate},
      name: name
    )
  end

  @impl GenServer
  def init(%{repo: repo, ref: ref, store: store, refresh_rate: refresh_rate}) do
    Logger.info("[Prismic.Cache] caching ref '#{ref}'")
    Prismic.Cache.Store.init_ref(store, ref)
    schedule_refresh(refresh_rate)

    {:ok, %{repo: repo, ref: ref, store: store, revision: nil, refresh_rate: refresh_rate},
     {:continue, :refresh}}
  end

  @impl GenServer
  def handle_continue(:refresh, state) do
    {:noreply, do_refresh(state, false)}
  end

  @impl GenServer
  def handle_cast({:refresh, force}, state) do
    {:noreply, do_refresh(state, force)}
  end

  def do_refresh(state, force \\ false) do
    Logger.info("[Prismic.Cache] refreshing...")
    %{repo: repo, ref: ref} = state
    client = repo.client(ref)
    revision = Prismic.API.ref(client)

    if !force && revision == state.revision do
      state
    else
      if state.revision == nil do
        Logger.info("[Prismic.Cache] Init loading revision #{revision}")
      else
        Logger.info(
          "[Prismic.Cache] Changes detected migrating from #{state.revision} to #{revision}"
        )
      end

      for {type, _mod} <- repo.content_types() do
        records = repo.fetch_by_type(client, type)
        :ok = Prismic.Cache.Store.insert(state.store, revision, records)
      end

      :ok = Prismic.Cache.Store.commit(state.store, state.ref, revision)
      %{state | revision: revision}
    end
  rescue
    e ->
      Logger.warning("[Prismic.Cache] Error encountered during refresh - #{inspect(e)}")
      state
  end

  @impl GenServer
  def handle_info(:refresh, %{refresh_rate: delay} = state) do
    schedule_refresh(delay)
    {:noreply, state, {:continue, :refresh}}
  end

  defp schedule_refresh(ms) when is_integer(ms), do: Process.send_after(self(), :refresh, ms)
  defp schedule_refresh(_), do: nil
end
