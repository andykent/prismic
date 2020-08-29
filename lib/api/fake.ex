defmodule Prismic.API.Fake do
  @behaviour Prismic.API

  def client(config, ref_id) do
    {%{type: "Fake", config: config}, "MOCK-" <> ref_id}
  end

  def list_by_type(_client, _type), do: []
end
