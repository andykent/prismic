defmodule Prismic.Cache.Store do
  # layout
  # {:revision, "sb43grw"} => ["master"]
  # {:ref, "master"} => "sb43grw"
  # {:record, "sb43grw", :project, "uid-1234-1234-1234"} => %Project{...}
  # {:index, "sb43grw", :project, :uid, "a-slug"} => "uid-1234-1234-1234"
  use GenServer

  require Logger

  def init_ref(store, ref) do
    Logger.info("[Prismic.Cache] initialising ref '#{ref}' for '#{inspect(store)}'")
    # GenServer.call(__MODULE__, :init_ref)
  end

  def insert(store, revision, records) do
    GenServer.call(store, {:insert, revision, records})
  end

  def commit(store, ref, revision) do
    GenServer.call(store, {:commit, ref, revision})
  end

  # def drop_ref(store, ref) do
  # end

  @spec fetch(any, any, any) :: any
  def fetch(store, revision, type) do
    case fetch_all(store, revision, type) do
      {:ok, [record]} -> {:ok, record}
      {:ok, r} -> {:error, "Expected one record of type #{inspect(type)}, got #{length(r)}"}
    end
  end

  @spec fetch(any, any, any, any) :: any
  def fetch(store, revision, type, {index, value}) do
    case get(store, {:index, revision, type, index, value}) do
      {:ok, id} -> fetch(store, revision, type, id)
      error -> error
    end
  end

  def fetch(store, revision, type, id) do
    get(store, {:record, revision, type, id})
  end

  def fetch_all(store, revision, type) do
    matches = :ets.match(store, {{:record, revision, type, :_}, :"$1"})
    records = for [record] <- matches, do: record
    {:ok, records}
  end

  def current_revision(store, ref) do
    get(store, {:ref, ref})
  end

  def dump(store) do
    :ets.tab2list(store)
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    table = Keyword.fetch!(opts, :table)
    GenServer.start_link(__MODULE__, %{table: table}, name: name)
  end

  @impl GenServer
  def init(%{table: table}) do
    Logger.info("[Prismic.Cache] creating table '#{table}'")
    create_table(table)
    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_call({:insert, rev, records}, _from, %{table: table} = state) do
    for record <- records do
      type = Prismic.Record.content_type(record)
      id = Prismic.Record.identity(record)
      :ets.insert(table, {{:record, rev, type, id}, record})
      indexes = Prismic.Record.indexes(record)
      index_data = for({index, val} <- indexes, do: {{:index, rev, type, index, val}, id})
      :ets.insert(table, index_data)
    end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:commit, ref, new_revision}, _from, %{table: table} = state) do
    updated_new_revision_refs =
      case get(table, {:revision, new_revision}) do
        {:ok, new_revision_refs} -> Enum.uniq([ref | new_revision_refs])
        _ -> [ref]
      end

    case get(table, {:ref, ref}) do
      {:ok, old_revision} ->
        old_revision_refs = get!(table, {:revision, old_revision})
        updated_old_revision_refs = Enum.filter(old_revision_refs, fn r -> r != ref end)

        :ets.insert(table, [
          {{:revision, old_revision}, updated_old_revision_refs},
          {{:revision, new_revision}, updated_new_revision_refs},
          {{:ref, ref}, new_revision}
        ])

        Process.send_after(self(), {:cleanup, old_revision}, 1_000)

      _ ->
        :ets.insert(table, [
          {{:revision, new_revision}, updated_new_revision_refs},
          {{:ref, ref}, new_revision}
        ])
    end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:cleanup, revision}, %{table: table} = state) do
    revision_key = {:revision, revision}

    case get(table, revision_key) do
      {:ok, []} ->
        for [type, uid] <- :ets.match(table, {{:record, revision, :"$1", :"$2"}, :_}) do
          :ets.delete(table, {:record, revision, type, uid})
        end

        :ets.delete(table, revision_key)

      _ ->
        nil
    end

    {:noreply, state}
  end

  defp create_table(tab) do
    table = :ets.new(tab, [:named_table, read_concurrency: true])
    table
  end

  defp get!(tab, key) do
    case get(tab, key) do
      {:ok, record} -> record
      {:error, error} -> raise(error)
    end
  end

  defp get(tab, key) do
    case :ets.lookup(tab, key) do
      [{^key, record}] -> {:ok, record}
      [] -> {:error, "no record found for: #{inspect(key)}"}
    end
  end
end
