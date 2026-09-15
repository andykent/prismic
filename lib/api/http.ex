defmodule Prismic.API.HTTP do
  @moduledoc """
  The `Prismic.API` implementation that talks to a Prismic repository over HTTP with
  `Req`.

  `config` carries the `:repository_url` and `:access_token`, and optionally
  `:req_options`, Req options merged onto every request, such as a `:finch` instance,
  timeouts or a `Req.Test` plug. By default a request waits ten seconds for a response
  and is retried up to ten times, backing off from 100ms to four seconds, on a 5xx, a
  408 or 429, or a dropped connection.
  """
  @behaviour Prismic.API

  @page_size 100

  @impl Prismic.API
  def fetch_repository(config) do
    case Req.get(base_request(config), url: "/api/v2") do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status, body: body}} -> {:error, {:status, status, body}}
      {:error, error} -> {:error, error}
    end
  end

  @impl Prismic.API
  def client(config, ref_id) do
    case fetch_repository(config) do
      {:ok, %{"refs" => refs}} ->
        ref = match_ref(refs, ref_id)
        {Req.merge(base_request(config), params: [ref: ref]), ref}

      {:error, error} ->
        raise "Unable to fetch the Prismic repository: #{inspect(error)}"
    end
  end

  @impl Prismic.API
  def list_by_type({client, _ref}, type) do
    search(client, "[[at(document.type,\"#{type}\")]]")
  end

  @doc false
  def retry_delay(retry_count), do: min(100 * Integer.pow(2, retry_count), 4_000)

  defp base_request(config) do
    [
      base_url: Keyword.fetch!(config, :repository_url),
      params: [access_token: Keyword.fetch!(config, :access_token)],
      receive_timeout: 10_000,
      retry: :safe_transient,
      max_retries: 10,
      retry_delay: &__MODULE__.retry_delay/1,
      retry_log_level: :warning
    ]
    |> Req.new()
    |> Req.merge(Keyword.get(config, :req_options, []))
  end

  defp search(client, query, page \\ 1) do
    {results, next_page} = search_page!(client, query, page)

    if next_page do
      results ++ search(client, query, next_page)
    else
      results
    end
  end

  defp search_page!(client, query, page) do
    response =
      Req.get(client,
        url: "/api/v2/documents/search",
        params: [q: query, pageSize: @page_size, page: page]
      )

    case response do
      {:ok, %Req.Response{status: 200, body: %{"results" => results, "next_page" => next_page}}} ->
        {results, if(next_page, do: page + 1, else: nil)}

      {:ok, %Req.Response{status: status, body: body}} ->
        raise "Prismic search failed with status #{status}: #{inspect(body)}"

      {:error, %{__exception__: true} = error} ->
        raise error

      {:error, error} ->
        raise "Prismic search failed: #{inspect(error)}"
    end
  end

  defp match_ref(refs, "Master") do
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
end
