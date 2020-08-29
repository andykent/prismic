defmodule Prismic.Cache.RefCache do
  use GenServer

  require Logger

  @refresh_rate 1 * 60 * 1000

  def refresh do
    GenServer.cast(__MODULE__, {:refresh, false})
  end

  @doc "Trigger a refresh and force pull changes regardless of if the ref has changed or not"
  def refresh! do
    GenServer.cast(__MODULE__, {:refresh, true})
  end

  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    repo = Keyword.fetch!(opts, :repo)
    ref = Keyword.fetch!(opts, :ref)
    store = Keyword.fetch!(opts, :store)
    GenServer.start_link(__MODULE__, %{repo: repo, ref: ref, store: store})
  end

  @impl GenServer
  def init(%{repo: repo, ref: ref, store: store}) do
    Logger.info("[Prismic.Cache] caching ref '#{ref}'")
    Prismic.Cache.Store.init_ref(store, ref)
    schedule_refresh()

    {:ok, %{repo: repo, ref: ref, store: store, revision: nil}, {:continue, :refresh}}
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

    # rescue
    #   e ->
    #     Logger.warn("[Prismic.Cache] Error encountered during refresh - #{inspect(e)}")
    #     Sentry.capture_exception(e, stacktrace: __STACKTRACE__)
    #     state
  end

  @impl GenServer
  def handle_info(:refresh, state) do
    schedule_refresh()
    {:noreply, state, {:continue, :refresh}}
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_rate)
  end
end
