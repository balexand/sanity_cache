defmodule Sanity.Behaviour do
  @callback request!(Request.t(), keyword()) :: {:ok, Response.t()} | {:error, Response.t()}
end

Mox.defmock(MockSanity, for: Sanity.Behaviour)

defmodule MyMod do
  use Sanity.Cache

  defrequest :page,
    config_key: :test_config,
    fetch_query: ~S'*[_type == "page" && path.current == $key && !(_id in path("drafts.**"))]',
    list_query: ~S'*[_type == "page" && !(_id in path("drafts.**"))]',
    projection: "{ ... }",
    lookup: [path: & &1.path.current]
end

defmodule Sanity.CacheTest do
  use ExUnit.Case

  alias Sanity.Cache.{CacheServer, NotFoundError}
  import Mox

  setup :verify_on_exit!

  setup do
    Application.put_env(:sanity_cache, :test_config, dataset: "production", project_id: "abc")
    Application.put_env(:sanity_cache, :sanity_client, MockSanity)

    :ok
  end

  describe "cache table exists" do
    setup do
      CacheServer.put_table(:page_by_path, %{"two" => "the value"})
      :ok
    end

    test "get_page_by_path! found in cache" do
      assert MyMod.get_page_by_path!("two") == {:ok, "the value"}
    end

    test "get_page_by_path! not found in cache" do
      assert_raise NotFoundError, "can't find document in cache with key \"one\"", fn ->
        MyMod.get_page_by_path!("one")
      end
    end
  end

  describe "cache table doesn't exist" do
    setup do
      CacheServer.delete_table(:page_by_path)
      :ok
    end

    test "get_page_by_path! fetched and found" do
      Mox.expect(MockSanity, :request!, fn _, _ ->
        %Sanity.Response{body: %{"result" => [%{"_id" => "id_x"}]}}
      end)

      assert MyMod.get_page_by_path!("one") == {:ok, %{_id: "id_x"}}
    end

    test "get_page_by_path! fetched and not found" do
      Mox.expect(MockSanity, :request!, fn _, _ ->
        %Sanity.Response{body: %{"result" => []}}
      end)

      assert_raise NotFoundError, "can't find document with key \"one\"", fn ->
        MyMod.get_page_by_path!("one")
      end
    end
  end
end
