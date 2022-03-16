defmodule Sanity.Cache.MixProject do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :sanity_cache,
      description:
        "Opinionated library for caching Sanity CMS content in an ETS table for submillisecond response times.",
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/balexand/sanity_cache"}
      ],
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_ref: "v#{@version}",
        source_url: "https://github.com/balexand/sanity_cache"
      ]
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
      {:plug, "~> 1.13"},
      {:nimble_options, "~> 0.4.0"},
      {:sanity, "~> 0.8"},

      # dev/test
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
