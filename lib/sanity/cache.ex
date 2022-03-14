defmodule Sanity.Cache do
  @doc false
  defmacro __using__([]) do
    quote do
      import Sanity.Cache, only: [defq: 2]

      Module.register_attribute(__MODULE__, :sanity_cache_update_opts, accumulate: true)

      @before_compile Sanity.Cache
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def child_spec(_) do
        %{
          id: __MODULE__,
          start: {Sanity.Cache.Poller, :start_link, [@sanity_cache_update_opts]}
        }
      end

      def update_all(opts \\ []) do
        Enum.each(@sanity_cache_update_opts, fn update_opts ->
          Map.merge(Map.new(opts), Map.new(update_opts))
          |> Map.to_list()
          |> Sanity.Cache.update()
        end)
      end
    end
  end

  @common_opts_validation [
    config_key: [
      type: :atom,
      default: :default
    ],
    projection: [
      type: :string,
      required: true
    ]
  ]

  @fetch_opts_validation Keyword.merge(@common_opts_validation,
                           fetch_query: [
                             type: :string,
                             required: true
                           ]
                         )

  @list_query_validation [
    type: :string,
    required: true
  ]

  @fetch_pairs_opts_validation Keyword.merge(@common_opts_validation,
                                 list_query: @list_query_validation,
                                 lookup_keys: [
                                   type: {:list, :atom},
                                   required: true
                                 ]
                               )

  @defq_opts_validation Keyword.merge(@fetch_opts_validation,
                          list_query: @list_query_validation,
                          lookup: [
                            type: :keyword_list,
                            required: true
                          ]
                        )

  @doc """
  Defines a Sanity query.

  ## Options

  #{NimbleOptions.docs(@defq_opts_validation)}
  """
  defmacro defq(name, opts) when is_atom(name) do
    Enum.map(Keyword.fetch!(opts, :lookup), fn {lookup_name, lookup_keys} ->
      table = :"#{name}_by_#{lookup_name}"
      fetch_pairs = :"fetch_#{table}_pairs"

      quote do
        NimbleOptions.validate!(unquote(opts), unquote(@defq_opts_validation))

        Module.put_attribute(__MODULE__, :sanity_cache_update_opts,
          fetch_pairs_mfa: {__MODULE__, unquote(fetch_pairs), []},
          table: unquote(table)
        )

        def unquote(fetch_pairs)() do
          opts =
            Keyword.take(unquote(opts), Keyword.keys(unquote(@fetch_pairs_opts_validation)))
            |> Keyword.put(:lookup_keys, unquote(lookup_keys))

          Sanity.Cache.fetch_pairs(opts)
        end

        def unquote(:"get_#{table}")(key) do
          opts = Keyword.take(unquote(opts), Keyword.keys(unquote(@fetch_opts_validation)))

          Sanity.Cache.get(unquote(table), key, opts)
        end

        def unquote(:"get_#{table}!")(key) do
          opts = Keyword.take(unquote(opts), Keyword.keys(unquote(@fetch_opts_validation)))

          Sanity.Cache.get!(unquote(table), key, opts)
        end
      end
    end)
  end

  defmodule NotFoundError do
    defexception [:message]

    defimpl Plug.Exception do
      def status(_), do: :not_found
      def actions(_), do: []
    end
  end

  require Logger
  alias Sanity.Cache.CacheServer

  @doc """
  Gets a single document using cache. If the cache table doesn't exist then `fetch/2` will be
  called. Returns `{:ok, value}` or `{:error, :not_found}`.
  """
  def get(table, key, opts) when is_atom(table) do
    case CacheServer.fetch(table, key) do
      {:error, :no_table} ->
        fetch(key, opts)

      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, result} ->
        {:ok, result}
    end
  end

  @doc """
  Like `get/3` except raises if not found.
  """
  def get!(table, key, opts) do
    case get(table, key, opts) do
      {:ok, value} -> value
      {:error, :not_found} -> raise NotFoundError, "can't find document with key #{inspect(key)}"
    end
  end

  @doc """
  Fetches a single document by making a request to the Sanity CMS API. The cache is not used.

  ## Options

  #{NimbleOptions.docs(@fetch_opts_validation)}
  """
  def fetch(key, opts) do
    opts = NimbleOptions.validate!(opts, @fetch_opts_validation)

    config_key = Keyword.fetch!(opts, :config_key)
    fetch_query = Keyword.fetch!(opts, :fetch_query)
    projection = Keyword.fetch!(opts, :projection)

    sanity = Application.get_env(:sanity_cache, :sanity_client, Sanity)

    Enum.join([fetch_query, projection], " | ")
    |> Sanity.query(%{key: key})
    |> sanity.request!(Application.fetch_env!(:sanity_cache, config_key))
    |> Sanity.result!()
    |> Sanity.atomize_and_underscore()
    |> case do
      [doc] -> {:ok, doc}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Fetches list of key/value pairs.

  ## Options

  #{NimbleOptions.docs(@fetch_pairs_opts_validation)}
  """
  def fetch_pairs(opts) do
    opts = NimbleOptions.validate!(opts, @fetch_pairs_opts_validation)

    config_key = Keyword.fetch!(opts, :config_key)
    list_query = Keyword.fetch!(opts, :list_query)
    lookup_keys = Keyword.fetch!(opts, :lookup_keys)
    projection = Keyword.fetch!(opts, :projection)

    sanity = Application.get_env(:sanity_cache, :sanity_client, Sanity)

    sanity_config =
      Application.fetch_env!(:sanity_cache, config_key)
      |> Keyword.put_new(:http_options, receive_timeout: 45_000)

    Enum.join([list_query, projection], " | ")
    |> Sanity.query()
    |> sanity.request!(sanity_config)
    |> Sanity.result!()
    |> Sanity.atomize_and_underscore()
    |> Enum.map(&{get_in(&1, lookup_keys), &1})
  end

  @update_opts_validation [
    fetch_pairs_mfa: [
      type: :mfa,
      required: true
    ],
    table: [
      type: :atom,
      required: true
    ],
    update_remote_nodes: [
      type: :boolean,
      default: false
    ]
  ]

  @doc """
  Updates a cache table.

  ## Options

  #{NimbleOptions.docs(@update_opts_validation)}
  """
  def update(opts) do
    opts = NimbleOptions.validate!(opts, @update_opts_validation)

    update_remote_nodes = Keyword.fetch!(opts, :update_remote_nodes)
    {module, function_name, args} = Keyword.fetch!(opts, :fetch_pairs_mfa)
    table = Keyword.fetch!(opts, :table)

    pairs = apply(module, function_name, args)

    if update_remote_nodes do
      Enum.each(Node.list(), fn node ->
        Logger.info("updating #{table} on remote node #{inspect(node)}")

        CacheServer.cast_put_table({CacheServer, node}, table, pairs)
      end)
    end

    Logger.info("updating #{table} on local node")
    CacheServer.put_table(table, pairs)
  end
end
