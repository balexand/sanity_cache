defmodule Sanity.Behaviour do
  @callback request!(Request.t(), keyword()) :: {:ok, Response.t()} | {:error, Response.t()}
end

Mox.defmock(MockSanity, for: Sanity.Behaviour)

defmodule MyMod do
  use Sanity.Cache

  defq :page,
    config_key: :test_config,
    fetch_query: ~S'*[_type == "page" && path.current == $key && !(_id in path("drafts.**"))]',
    list_query: ~S'*[_type == "page" && !(_id in path("drafts.**"))]',
    projection: "{ ... }",
    lookup: [path: [:path, :current]]
end

defmodule Sanity.CacheTest do
  use ExUnit.Case

  alias Sanity.Cache
  alias Sanity.Cache.{CacheServer, NotFoundError}
  import Mox

  setup :verify_on_exit!

  setup do
    Application.put_env(:sanity_cache, :test_config, dataset: "production", project_id: "abc")
    Application.put_env(:sanity_cache, :sanity_client, MockSanity)

    CacheServer.delete_table(:page_by_path)

    :ok
  end

  test "child_spec" do
    assert MyMod.child_spec([]) == %{
             id: MyMod,
             start:
               {Sanity.Cache.Poller, :start_link,
                [
                  [
                    [
                      fetch_pairs_mfa: {MyMod, :fetch_page_by_path_pairs, []},
                      table: :page_by_path
                    ]
                  ]
                ]}
           }
  end

  describe "cache table exists" do
    setup do
      CacheServer.put_table(:page_by_path, %{"two" => "the value"})
      :ok
    end

    test "get_page_by_path found in cache" do
      assert MyMod.get_page_by_path("two") == {:ok, "the value"}
    end

    test "get_page_by_path not found in cache" do
      assert MyMod.get_page_by_path("one") == {:error, :not_found}
    end

    test "get_page_by_path! found in cache" do
      assert MyMod.get_page_by_path!("two") == "the value"
    end

    test "get_page_by_path! not found in cache" do
      assert_raise NotFoundError, "can't find document with key \"one\"", fn ->
        MyMod.get_page_by_path!("one")
      end
    end
  end

  describe "cache table doesn't exist" do
    test "get_page_by_path fetched and found" do
      Mox.expect(MockSanity, :request!, fn request, [dataset: "production", project_id: "abc"] ->
        assert request == %Sanity.Request{
                 endpoint: :query,
                 method: :get,
                 query_params: %{
                   "$key" => "\"one\"",
                   "query" =>
                     "*[_type == \"page\" && path.current == $key && !(_id in path(\"drafts.**\"))] | { ... }"
                 }
               }

        %Sanity.Response{body: %{"result" => [%{"_id" => "id_x"}]}}
      end)

      assert MyMod.get_page_by_path("one") == {:ok, %{_id: "id_x"}}
    end

    test "get_page_by_path fetched and not found" do
      Mox.expect(MockSanity, :request!, fn _, _ ->
        %Sanity.Response{body: %{"result" => []}}
      end)

      assert MyMod.get_page_by_path("one") == {:error, :not_found}
    end

    test "get_page_by_path! fetched and found" do
      Mox.expect(MockSanity, :request!, fn _, _ ->
        %Sanity.Response{body: %{"result" => [%{"_id" => "id_x"}]}}
      end)

      assert MyMod.get_page_by_path!("one") == %{_id: "id_x"}
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

  test "fetch_page_by_path_pairs" do
    Mox.expect(MockSanity, :request!, fn request, [dataset: "production", project_id: "abc"] ->
      assert request == %Sanity.Request{
               endpoint: :query,
               method: :get,
               query_params: %{
                 "query" => "*[_type == \"page\" && !(_id in path(\"drafts.**\"))] | { ... }"
               }
             }

      %Sanity.Response{
        body: %{"result" => [%{"_id" => "id_x", "path" => %{"current" => "/my-path"}}]}
      }
    end)

    assert MyMod.fetch_page_by_path_pairs() == [
             {"/my-path", %{_id: "id_x", path: %{current: "/my-path"}}}
           ]
  end

  test "fetch_pairs" do
    Mox.expect(MockSanity, :request!, fn request, [dataset: "production", project_id: "abc"] ->
      assert request == %Sanity.Request{
               endpoint: :query,
               method: :get,
               query_params: %{
                 "query" => "*[_type == \"page\" && !(_id in path(\"drafts.**\"))] | { ... }"
               }
             }

      %Sanity.Response{
        body: %{"result" => [%{"_id" => "id_x", "path" => %{"current" => "/my-path"}}]}
      }
    end)

    assert Cache.fetch_pairs(
             config_key: :test_config,
             projection: "{ ... }",
             list_query: ~S'*[_type == "page" && !(_id in path("drafts.**"))]',
             lookup_keys: [:path, :current]
           ) == [{"/my-path", %{_id: "id_x", path: %{current: "/my-path"}}}]
  end
end
