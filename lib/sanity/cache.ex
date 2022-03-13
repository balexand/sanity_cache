defmodule Sanity.Cache do
  @doc false
  defmacro __using__([]) do
    quote do
      import Sanity.Cache, only: [defrequest: 1]

      Module.register_attribute(__MODULE__, :sanity_cache_names, accumulate: true)

      @before_compile Sanity.Cache
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      # FIXME use this data to start pollers; probably return a child spec here that starts a
      # supervisor containing pollers
      def __sanity_cache_names__ do
        Enum.reverse(@sanity_cache_names)
      end
    end
  end

  @doc """
  TODO write doc
  """
  defmacro defrequest(opts) do
    # FIXME nimble options for opts
    quote do
      Module.put_attribute(__MODULE__, :sanity_cache_names, Keyword.fetch!(unquote(opts), :name))

      def unquote(Keyword.fetch!(opts, :name))(key) do
        Sanity.Cache.get(key, unquote(opts))
      end
    end
  end

  defmodule NotFoundError do
    defexception [:message]
  end

  # FIXME nimble options for functions; same as defrequest opts except requires :config_key opt

  @doc """
  Gets a single document using cache.
  """
  def get(key, opts) do
    name = Keyword.fetch!(opts, :name)

    case Example.Cache.get(name, key) do
      {:error, :no_data} ->
        fetch(key, opts)

      {:ok, result} ->
        # FIXME handle found and not found
        result
    end
  end

  @doc """
  Fetches a single document without cache.
  """
  def fetch(key, opts) do
    fetch_query = Keyword.fetch!(opts, :fetch_query)
    projection = Keyword.fetch!(opts, :projection)

    Enum.join([fetch_query, projection])
    |> Sanity.query(%{key: key})
    |> request!()
    |> case do
      [doc] -> doc
      [] -> raise NotFoundError, "can't find document with key #{inspect(key)}"
    end
  end

  @doc """
  Lists all documents without cache.
  """
  def list(_opts) do
  end

  defp request!(request) do
    # FIXME Application.fetch_env!(:sanity_cache, config_key); config_key will be name of module
    # when using macros
    request
    |> Sanity.request!(Application.fetch_env!(:example, :sanity))
    |> Sanity.result!()
    |> Sanity.atomize_and_underscore()
  end
end
