defmodule Prismic.API.HTTPTest do
  use ExUnit.Case, async: true

  alias Prismic.API.HTTP

  @config [
    repository_url: "https://example.cdn.prismic.io",
    access_token: "token",
    req_options: [plug: {Req.Test, HTTP}]
  ]

  @config_without_retries Keyword.update!(@config, :req_options, &(&1 ++ [retry: false]))

  @repository %{
    "refs" => [
      %{"id" => "master", "ref" => "MASTER-REF", "label" => "Master", "isMasterRef" => true},
      %{"id" => "beta-id", "ref" => "BETA-REF", "label" => "Beta", "isMasterRef" => false}
    ]
  }

  describe "fetch_repository/1" do
    test "fetches the repository description with the access token" do
      Req.Test.stub(HTTP, fn conn ->
        assert %Plug.Conn{
                 host: "example.cdn.prismic.io",
                 request_path: "/api/v2",
                 query_string: "access_token=token"
               } = conn

        Req.Test.json(conn, @repository)
      end)

      assert {:ok, @repository} = HTTP.fetch_repository(@config)
    end

    test "returns the status when the repository cannot be read" do
      Req.Test.stub(HTTP, fn conn ->
        conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "Invalid access token"})
      end)

      assert {:error, {:status, 401, %{"error" => "Invalid access token"}}} =
               HTTP.fetch_repository(@config)
    end

    test "returns the transport error when the repository cannot be reached" do
      Req.Test.stub(HTTP, fn conn -> Req.Test.transport_error(conn, :timeout) end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               HTTP.fetch_repository(@config_without_retries)
    end
  end

  describe "client/2" do
    setup do
      Req.Test.stub(HTTP, fn conn -> Req.Test.json(conn, @repository) end)
      :ok
    end

    test "resolves the master ref" do
      assert {%Req.Request{}, "MASTER-REF"} = HTTP.client(@config, "Master")
    end

    test "resolves a ref by label or id" do
      assert {_client, "BETA-REF"} = HTTP.client(@config, "Beta")
      assert {_client, "BETA-REF"} = HTTP.client(@config, "beta-id")
    end

    test "raises for an unknown ref, listing the available ones" do
      assert_raise RuntimeError,
                   ~r/No prismic ref with id Nope found.*master, beta-id, Master, Beta/,
                   fn ->
                     HTTP.client(@config, "Nope")
                   end
    end

    test "raises when the repository cannot be fetched" do
      Req.Test.stub(HTTP, fn conn -> Req.Test.transport_error(conn, :econnrefused) end)

      assert_raise RuntimeError, ~r/Unable to fetch the Prismic repository/, fn ->
        HTTP.client(@config_without_retries, "Master")
      end
    end
  end

  describe "list_by_type/2" do
    test "searches by document type at the client's ref and follows pagination" do
      Req.Test.stub(HTTP, fn conn ->
        case conn.request_path do
          "/api/v2" ->
            Req.Test.json(conn, @repository)

          "/api/v2/documents/search" ->
            params = URI.decode_query(conn.query_string)

            assert %{
                     "access_token" => "token",
                     "ref" => "MASTER-REF",
                     "q" => "[[at(document.type,\"scene\")]]",
                     "pageSize" => "100"
                   } = params

            case params["page"] do
              "1" ->
                Req.Test.json(conn, %{
                  "page" => 1,
                  "next_page" => "p2",
                  "results" => [%{"id" => "a"}]
                })

              "2" ->
                Req.Test.json(conn, %{
                  "page" => 2,
                  "next_page" => nil,
                  "results" => [%{"id" => "b"}]
                })
            end
        end
      end)

      client = HTTP.client(@config, "Master")

      assert [%{"id" => "a"}, %{"id" => "b"}] = HTTP.list_by_type(client, "scene")
    end

    test "raises when a search page fails" do
      Req.Test.stub(HTTP, fn conn ->
        case conn.request_path do
          "/api/v2" -> Req.Test.json(conn, @repository)
          _ -> conn |> Plug.Conn.put_status(400) |> Req.Test.json(%{"error" => "bad query"})
        end
      end)

      client = HTTP.client(@config, "Master")

      assert_raise RuntimeError, ~r/Prismic search failed with status 400/, fn ->
        HTTP.list_by_type(client, "scene")
      end
    end
  end

  describe "retries" do
    test "retries a transient failure with a backoff starting at 100ms" do
      attempts = :counters.new(1, [])

      Req.Test.stub(HTTP, fn conn ->
        :counters.add(attempts, 1, 1)

        case :counters.get(attempts, 1) do
          1 -> Plug.Conn.send_resp(conn, 503, "unavailable")
          _ -> Req.Test.json(conn, @repository)
        end
      end)

      assert {:ok, @repository} = HTTP.fetch_repository(@config)
      assert :counters.get(attempts, 1) == 2
    end

    test "backs off exponentially and caps at four seconds" do
      assert Enum.map(0..6, &HTTP.retry_delay/1) == [100, 200, 400, 800, 1600, 3200, 4000]
    end
  end
end
