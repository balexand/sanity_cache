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
  # ...
  import_deps: [:sanity_cache]
]
```

## Configuration

```elixir
# config.exs or runtime.exs
config :sanity_cache, :default,
  dataset: "production",
  project_id: "project-id-from-sanity",
  token: "api-token-with-read-permission"
```

If you need to connect to mulitiple Sanity CMS datasets then you can use a key other than `:default` and set the `:config_key` opt when calling [`defq`](https://hexdocs.pm/sanity_cache/Sanity.Cache.html#defq/2).

## Usage

### Basic usage

Create a module in your application like:

```elixir
defmodule MyApp.CMS do
  @page_projection "{ ... }"

  use Sanity.Cache

  defq :page,
    list_query: ~S'*[_type == "page" && !(_id in path("drafts.**"))]',
    projection: @page_projection,
    lookup: [
      id: [
        fetch_query: ~S'*[_type == "page" && _id == $key]',
        keys: [:_id]
      ],
      path: [
        fetch_query:
          ~S'*[_type == "page" && path.current == $key && !(_id in path("drafts.**"))]',
        keys: [:path, :current]
      ]
    ]
end
```

This generates the following functions:

* `MyApp.CMS.child_spec/1`
* `MyApp.CMS.get_page_by_id/1`
* `MyApp.CMS.get_page_by_id!/1`
* `MyApp.CMS.get_page_by_path/1`
* `MyApp.CMS.get_page_by_path!/1`
* `MyApp.CMS.update_all/1`

At this point no caching is taking place. Each call to a function like `MyApp.CMS.get_page_by_path/1` will make a request to the Sanity CMS API.

### Polling for new content

Add `MyApp.CMS` to start when your application starts. This will fetch content when your application starts and poll for new content every few minutes. Now, functions like `MyApp.CMS.get_page_by_path/1` will get data from the cache instead of making calls to the Sanity CMS API.

A useful trick is to not start this process during development so you will get fetch CMS data every time you refresh the page.

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # ...
        MyApp.CMS
      ]

    # ...
  end
```

### Instantly updating cached content using Sanity webhooks

TODO
