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
    search(client, "[[at(document.type,\"#{type}\")]]")
  end

  defp search(client, query, page \\ 1) do
    {results, next_page} =
      client
      |> get_search(query, page)
      |> parse_search_response!()

    if next_page do
      results = [results | search(client, query, next_page)]

      if page == 1 do
        List.flatten(results)
      else
        results
      end
    else
      results
    end
  end

  defp parse_search_response!(response) do
    case response do
      {:ok, %{body: %{"results" => results, "next_page" => next_page, "page" => page}}} ->
        {results, if(next_page, do: page + 1, else: nil)}

      e ->
        raise(e)
    end
  end

  defp get_search(client, query, page) do
    Tesla.get(client, "/api/v2/documents/search", query: [q: query, pageSize: 100, page: page])
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

      raise "No prismic ref with id #{ref_id} found, possible values are #{Enum.join(ids ++ labels, ", ")}"
    end

    ref_record["ref"]
  end

  defp should_retry?({:ok, %{status: status}}) when status < 300, do: false

  defp should_retry?(e) do
    Logger.warning("Prismic API request requires retry, got: #{inspect(e)}")
    true
  end
end
