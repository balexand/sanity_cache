defmodule Sanity.Cache do
  @doc false
  defmacro __using__([]) do
    quote do
      import Sanity.Cache, only: [defq: 2]

      Module.register_attribute(__MODULE__, :sanity_cache_names, accumulate: true)

      @before_compile Sanity.Cache
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      # FIXME use this data to start pollers; probably return a child spec here that starts a
      # supervisor containing pollers
      def child_spec do
        Enum.reverse(@sanity_cache_names)
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

  @list_opts_validation Keyword.merge(@common_opts_validation,
                          list_query: [
                            type: :string,
                            required: true
                          ]
                        )

  @defq_opts_validation Map.merge(Map.new(@fetch_opts_validation), Map.new(@list_opts_validation))
                        |> Map.to_list()
                        |> Keyword.merge(
                          lookup: [
                            type: :keyword_list,
                            default: []
                          ]
                        )

  @doc """
  TODO write doc
  """
  defmacro defq(name, opts) when is_atom(name) do
    Enum.map(Keyword.get(opts, :lookup, []), fn {lookup_name, _func} ->
      table = :"#{name}_by_#{lookup_name}"

      quote do
        NimbleOptions.validate!(unquote(opts), unquote(@defq_opts_validation))
        Module.put_attribute(__MODULE__, :sanity_cache_names, unquote(table))

        def unquote(:"get_#{table}")(key) do
          Sanity.Cache.get(
            unquote(table),
            key,
            Keyword.take(unquote(opts), Keyword.keys(unquote(@fetch_opts_validation)))
          )
        end

        def unquote(:"get_#{table}!")(key) do
          Sanity.Cache.get!(
            unquote(table),
            key,
            Keyword.take(unquote(opts), Keyword.keys(unquote(@fetch_opts_validation)))
          )
        end
      end
    end)
  end

  defmodule NotFoundError do
    defexception [:message]
  end

  alias Sanity.Cache.CacheServer

  @doc """
  Gets a single document using cache. Returns `{:ok, value}` or `{:error, :not_found}`.
  """
  def get(table, key, opts) when is_atom(table) do
    opts = NimbleOptions.validate!(opts, @fetch_opts_validation)

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
  Fetches a single document without cache.
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
  Lists all documents without cache.
  """
  def list(_opts) do
    # FIXME
  end
end
