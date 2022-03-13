defmodule Sanity.Cache.CacheServer do
  use GenServer

  @default_name __MODULE__

  ###
  # Client API
  ###

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @doc """
  Fetches a value from the cache. Returns one of the following
    * `{:ok, value}` if the item is found
    * `{:error, :no_table}` if the table doesn't exist
    * `{:error, :not_found}` if the table exists but doesn't contain the specified key
  """
  def fetch(pid \\ @default_name, table, key) when is_atom(table) do
    GenServer.call(pid, {:fetch, table, key})
  end

  def put(pid \\ @default_name, table, pairs) when is_atom(table) and is_list(pairs) do
    GenServer.call(pid, {:put, table, pairs})
  end

  ###
  # Server API
  ###

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:fetch, table, key}, _from, state) do
    {:reply, lookup(table, key), state}
  end

  def handle_call({:put, table, pairs}, _from, state) do
    case :ets.whereis(table) do
      :undefined -> nil
      tid -> :ets.delete(tid)
    end

    ^table = :ets.new(table, [:named_table])
    true = :ets.insert(table, pairs)

    {:reply, :ok, state}
  end

  defp lookup(table, key) do
    case :ets.lookup(table, key) do
      [] -> {:error, :not_found}
      [{_key, value}] -> {:ok, value}
    end
  rescue
    ArgumentError ->
      {:error, :no_table}
  end
end
