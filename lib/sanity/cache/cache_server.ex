defmodule Sanity.Cache.CacheServer do
  use GenServer

  @default_name __MODULE__

  ###
  # Client API
  ###

  @doc """
  See `GenServer.start_link/3`.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @doc """
  Deletes a table if it exists. Returns `:ok` or `{:error, :no_table}`.

  ## Examples

    iex> delete_table(:nonexistent_doctest_table)
    {:error, :no_table}
  """
  def delete_table(pid \\ @default_name, table) when is_atom(table) do
    GenServer.call(pid, {:delete_table, table})
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

  @doc """
  Creates or replaces a table with the given names. `pairs` must be a map or a list of key value
  pairs like `[{:my_key, :my_value}]`.

  ## Examples

    iex> put_table(:doctest_table, [{"key", "value"}])
    :ok
  """
  def put_table(pid \\ @default_name, table, pairs)

  def put_table(pid, table, %{} = map) when is_atom(table) do
    put_table(pid, table, Enum.to_list(map))
  end

  def put_table(pid, table, pairs) when is_atom(table) and is_list(pairs) do
    GenServer.call(pid, {:put_table, table, pairs})
  end

  ###
  # Server API
  ###

  @doc false
  @impl true
  def init(_) do
    {:ok, nil}
  end

  @doc false
  @impl true
  def handle_call({:delete_table, table}, _from, state) do
    {:reply, delete_if_exists(table), state}
  end

  def handle_call({:fetch, table, key}, _from, state) do
    {:reply, lookup(table, key), state}
  end

  def handle_call({:put_table, table, pairs}, _from, state) do
    replace_table(table, pairs)

    {:reply, :ok, state}
  end

  defp replace_table(table, pairs) do
    delete_if_exists(table)

    ^table = :ets.new(table, [:named_table])
    true = :ets.insert(table, pairs)
  end

  defp delete_if_exists(table) do
    case :ets.whereis(table) do
      :undefined ->
        {:error, :no_table}

      tid ->
        true = :ets.delete(tid)
        :ok
    end
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
