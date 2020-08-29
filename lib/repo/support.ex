defmodule Prismic.Repo.Support do
  alias Prismic.API

  def fetch_all(client, content_types) do
    for {type, mod} <- content_types, do: fetch(client, type, mod)
  end

  def fetch_by_type(client, content_types, type) do
    {type, mod} = find_type_and_module!(content_types, type)
    fetch(client, type, mod)
  end

  def fetch(client, type, mod) do
    prismic_data = API.list_by_type(client, type)
    for data <- prismic_data, do: apply(mod, :from_prismic, [data, API.ref(client)])
  end

  defp find_type_and_module!(content_types, type) do
    match =
      Enum.find(content_types, fn
        {^type, _} -> true
        {_, ^type} -> true
        _ -> false
      end)

    case match do
      {type, mod} -> {type, mod}
      nil -> raise "No type matching #{inspect(type)}, available types: #{inspect(content_types)}"
    end
  end

  def return_or_raise({:ok, record}), do: record
  def return_or_raise({:error, error}), do: raise(error)
end
