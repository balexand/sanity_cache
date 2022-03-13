defmodule Sanity.Cache.CacheServerTest do
  use ExUnit.Case, async: true

  alias Sanity.Cache.CacheServer

  setup do
    {:ok, pid} = CacheServer.start_link()
    %{pid: pid}
  end

  describe "fetch" do
    setup %{pid: pid} do
      CacheServer.put(pid, :my_table, [{"/", "home page"}])

      :ok
    end

    test "missing table", %{pid: pid} do
      assert CacheServer.fetch(pid, :does_not_exist, "key") == {:error, :no_table}
    end

    test "table doesn't contain key", %{pid: pid} do
      assert CacheServer.fetch(pid, :my_table, "wrong key") == {:error, :not_found}
    end

    test "table contains key", %{pid: pid} do
      assert CacheServer.fetch(pid, :my_table, "/") == {:ok, "home page"}
    end
  end

  test "put", %{pid: pid} do
    assert CacheServer.put(pid, :my_table, [{"/", "one"}]) == :ok

    assert CacheServer.fetch(pid, :my_table, "/") == {:ok, "one"}

    # replace table
    assert CacheServer.put(pid, :my_table, [{"/two", "two"}]) == :ok

    assert CacheServer.fetch(pid, :my_table, "/") == {:error, :not_found}
    assert CacheServer.fetch(pid, :my_table, "/two") == {:ok, "two"}
  end
end
