defmodule Sanity.Cache.Poller do
  @moduledoc false

  use GenServer

  alias Sanity.Cache.CacheServer

  require Logger

  @interval 120_000
  @task_supervisor Sanity.Cache.TaskSupervisor

  @state_validation [
    fetch_pairs_mfa: [
      type: :mfa,
      required: true
    ],
    table: [
      type: :atom,
      required: true
    ]
  ]

  def start_link(state) do
    state = Enum.map(state, &NimbleOptions.validate!(&1, @state_validation))

    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(state) do
    send(self(), :poll)

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    Process.send_after(self(), :poll, @interval)

    Enum.each(state, fn opts ->
      Task.Supervisor.start_child(@task_supervisor, fn ->
        {module, function_name, args} = Keyword.fetch!(opts, :fetch_pairs_mfa)
        table = Keyword.fetch!(opts, :table)

        Logger.info("polling for changes to table #{inspect(table)}")

        pairs = apply(module, function_name, args)
        CacheServer.put_table(table, pairs)
      end)
    end)

    {:noreply, state}
  end
end
