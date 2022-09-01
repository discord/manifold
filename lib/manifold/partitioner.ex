defmodule Manifold.Partitioner do
  use GenServer

  require Logger

  alias Manifold.{Worker, Utils}

  @gen_module Application.get_env(:manifold, :gen_module, GenServer)

  ## Client

  @spec child_spec(Keyword.t) :: tuple
  def child_spec(partitions, opts \\ []) do
    import Supervisor.Spec, warn: false
    supervisor(__MODULE__, [partitions, opts], id: Keyword.get(opts, :name, __MODULE__))
  end

  @spec start_link(Number.t, Keyword.t) :: GenServer.on_start
  def start_link(partitions, opts \\ []) do
    GenServer.start_link(__MODULE__, partitions, opts)
  end

  @spec send(pid, [pid], term) :: :ok
  def send(pid, pids, message) do
    @gen_module.cast(pid, {:send, pids, message})
  end

  @spec offload_send(pid, [pid], term) :: :ok
  def offload_send(pid, pids, message) do
    @gen_module.cast(pid, {:offload_send, pid, pids, message})
  end

  ## Server Callbacks

  def init(partitions) do
    # Set optimal process flags
    Process.flag(:trap_exit, true)
    Process.flag(:message_queue_data, :off_heap)
    workers = for _ <- 0..partitions do
      {:ok, pid} = Worker.start_link()
      pid
    end
    schedule_next_hibernate()
    {:ok, List.to_tuple(workers)}
  end

  def terminate(_reason, _state), do: :ok

  def handle_call(:which_children, _from, state) do
    children = for pid <- Tuple.to_list(state), is_pid(pid) do
      {:undefined, pid, :worker, [Worker]}
    end
    {:reply, children, state}
  end

  def handle_call(:count_children, _from, state) do
    {:reply, [
      specs: 1,
      active: tuple_size(state),
      supervisors: 0,
      workers: tuple_size(state)
    ], state}
  end

  def handle_call(_message, _from, state) do
    {:reply, :error, state}
  end

  # Specialize handling cast to a single pid.
  def handle_cast({:send, [pid], message}, state) do
    partition = Utils.partition_for(pid, tuple_size(state))
    Worker.send(elem(state, partition), [pid], message)
    {:noreply, state}
  end

  def handle_cast({:send, pids, message}, state) do
    partitions = tuple_size(state)
    pids_by_partition = Utils.partition_pids(pids, partitions)
    do_send(message, pids_by_partition, state, 0, partitions)
    {:noreply, state}
  end

  def handle_cast({:offload_send, partitioner_name, pids, message}, state) do
    grouped_by = Utils.group_by(pids, fn
      nil -> nil
      pid -> node(pid)
    end)
    for {node, pids} <- grouped_by, node != nil, do: Manifold.Partitioner.send({partitioner_name, node}, pids, message)
    {:noreply, state}
  end

  def handle_cast(_message, state) do
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.warn "manifold worker exited: #{inspect reason}"

    state = state
      |> Tuple.to_list
      |> Enum.map(fn
        ^pid -> Worker.start_link()
        pid -> pid
      end)
      |> List.to_tuple

    {:noreply, state}
  end

  def handle_info(:hibernate, state) do
    schedule_next_hibernate()
    {:noreply, state, :hibernate}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp do_send(_message, _pids_by_partition, _workers, partitions, partitions), do: :ok
  defp do_send(message, pids_by_partition, workers, partition, partitions) do
    pids = elem(pids_by_partition, partition)
    if pids != [] do
      Worker.send(elem(workers, partition), pids, message)
    end
    do_send(message, pids_by_partition, workers, partition + 1, partitions)
  end

  defp schedule_next_hibernate() do
    Process.send_after(self(), :hibernate, Utils.next_hibernate_delay())
  end
end
