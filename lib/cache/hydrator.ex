defmodule Prismic.Cache.Hydrator do
  def hydrate(store, data) do
    do_hydrate(store, data, true)
  end

  def hydrate_once(store, data) do
    do_hydrate(store, data, false)
  end

  defp do_hydrate(store, data, recur) when is_list(data) do
    for d <- data, do: do_hydrate(store, d, recur)
  end

  defp do_hydrate(store, %Prismic.Link{type: type, id: id, revision: revision}, recur) do
    case Prismic.Cache.Store.fetch(store, revision, type, id) do
      {:ok, record} -> if(recur, do: do_hydrate(store, record, true), else: record)
      {:error, err} -> raise err
    end
  end

  defp do_hydrate(store, %{} = record, recur) do
    record
    |> Map.to_list()
    |> Map.new(fn
      {k, v} -> {k, do_hydrate(store, v, recur)}
    end)
  end

  defp do_hydrate(_store, v, _recur) do
    v
  end
end
