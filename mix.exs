defmodule Sanity.Cache.MixProject do
  use Mix.Project

  def project do
    [
      app: :sanity_cache,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Sanity.Cache.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, "~> 0.4.0"},
      {:sanity, "~> 0.8"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
