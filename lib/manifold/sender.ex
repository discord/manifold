defmodule Manifold.Sender do
  use GenServer

  alias Manifold.Utils

  @gen_module Application.get_env(:manifold, :gen_module, GenServer)

  ## Client

  @spec child_spec(Keyword.t()) :: tuple
  def child_spec(opts \\ []) do
    import Supervisor.Spec, warn: false
    supervisor(__MODULE__, [:ok, opts], id: Keyword.get(opts, :name, __MODULE__))
  end

  @spec start_link(:ok, Keyword.t()) :: GenServer.on_start()
  def start_link(:ok, opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @spec send(pid, atom, [pid], term) :: :ok
  def send(pid, partitioner, pids, message) do
    @gen_module.cast(pid, {:send, partitioner, pids, message})
  end

  ## Server Callbacks

  def init(:ok) do
    # Set optimal process flags
    Process.flag(:message_queue_data, :off_heap)
    schedule_next_hibernate()
    {:ok, nil}
  end

  def handle_cast({:send, partitioner, pids, message}, nil) do
    grouped_by =
      Utils.group_by(pids, fn
        nil -> nil
        pid -> node(pid)
      end)

    for {node, pids} <- grouped_by, node != nil do
      Manifold.Partitioner.send({partitioner, node}, pids, message)
    end

    {:noreply, nil}
  end

  def handle_cast(_message, nil) do
    {:noreply, nil}
  end

  def handle_info(:hibernate, nil) do
    schedule_next_hibernate()
    {:noreply, nil, :hibernate}
  end

  def handle_info(_message, nil) do
    {:noreply, nil}
  end

  defp schedule_next_hibernate() do
    Process.send_after(self(), :hibernate, Utils.next_hibernate_delay())
  end
end
