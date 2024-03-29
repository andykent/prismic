defmodule Prismic.MixProject do
  use Mix.Project

  def project do
    [
      app: :prismic,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:hackney, "1.18.1"},
      {:phoenix_html, "3.2.0"},
      {:plug, "1.13.6"}
    ]
  end
end
