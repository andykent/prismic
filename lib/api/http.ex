defmodule Prismic.API.HTTP do
  @behaviour Prismic.API

  require Logger

  def client(config, ref_id) do
    middleware = [
      Tesla.Middleware.Logger,
      {Tesla.Middleware.BaseUrl, Keyword.fetch!(config, :repository_url)},
      {Tesla.Middleware.Query, access_token: Keyword.fetch!(config, :access_token)},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Retry,
       [
         should_retry: &should_retry?/1,
         max_retries: 10,
         delay: 100,
         max_delay: 4_000
       ]},
      {Tesla.Middleware.Timeout, timeout: 10_000}
    ]

    client = Tesla.client(middleware)
    {:ok, %{body: body}} = Tesla.get(client, "/api/v2")
    %{"refs" => refs} = body
    ref = match_ref(refs, ref_id)
    client = Tesla.client(middleware ++ [{Tesla.Middleware.Query, ref: ref}])
    {client, ref}
  end

  def list_by_type({client, _ref}, type) do
    case search(client, "[[at(document.type,\"#{type}\")]]") do
      {:ok, %{body: %{"results" => results}}} -> results
      e -> raise(e)
    end
  end

  defp search(client, query) do
    Tesla.get(client, "/api/v2/documents/search", query: [q: query, pageSize: 200])
  end

  defp match_ref(refs, "master") do
    master = Enum.find(refs, fn %{"isMasterRef" => is_master} -> is_master end)
    master["ref"]
  end

  defp match_ref(refs, ref_id) do
    ref_record =
      Enum.find(refs, fn
        %{"id" => ^ref_id} -> true
        %{"label" => ^ref_id} -> true
        _ -> false
      end)

    if ref_record == nil do
      ids = Enum.map(refs, fn %{"id" => id} -> id end)
      labels = Enum.map(refs, fn %{"label" => label} -> label end)

      raise "No prismic ref with id #{ref_id} found, possible values are #{
              Enum.join(ids ++ labels, ", ")
            }"
    end

    ref_record["ref"]
  end

  defp should_retry?({:ok, %{status: status}}) when status < 300, do: false

  defp should_retry?(e) do
    Logger.warn("Prismic API request requires retry, got: #{inspect(e)}")
    true
  end
end
