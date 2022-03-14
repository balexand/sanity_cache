defmodule Sanity.Cache.Poller do
  @moduledoc false

  use GenServer

  alias Sanity.Cache

  @interval 120_000
  @task_supervisor Sanity.Cache.TaskSupervisor

  def start_link(state) do
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
        Cache.update(opts)
      end)
    end)

    {:noreply, state}
  end
end
