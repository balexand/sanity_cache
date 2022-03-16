# `Sanity.Cache`

[![Package](https://img.shields.io/badge/-Package-important)](https://hex.pm/packages/sanity_cache) [![Documentation](https://img.shields.io/badge/-Documentation-blueviolet)](https://hexdocs.pm/sanity_cache)

Opinionated library for caching Sanity CMS content in an ETS table for submillisecond response times.

## Installation

The package can be installed by adding `sanity_cache` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sanity_cache, "~> 0.1.0"}
  ]
end
```

You may also want to add `sanity_cache` to your `.formatter.exs` file so that `defq` calls are formatted nicely.

```elixir
# .formatter.exs
[
  import_deps: [:sanity_cache]
  # ...
]
```

## Usage

### Basic usage

TODO

### Polling for new content

TODO

### Instantly updating cached content using Sanity webhooks

TODO
