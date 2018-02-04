defmodule Manifold.Partitioner do
  use GenServer

  require Logger

  alias Manifold.{Worker, Utils}

  @gen_module Application.get_env(:manifold, :gen_module, GenServer)

  ## Client

  @spec child_spec(Keyword.t) :: tuple
  def child_spec(partitions, opts \\ []) do
    import Supervisor.Spec, warn: false
    supervisor(__MODULE__, [partitions, opts])
  end

  @spec start_link(Number.t, Keyword.t) :: GenServer.on_start
  def start_link(partitions, opts \\ []) do
    GenServer.start_link(__MODULE__, partitions, opts)
  end

  @spec send(pid, [pid], term) :: :ok
  def send(pid, pids, message) do
    @gen_module.cast(pid, {:send, pids, message})
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

  def handle_cast({:send, pids, message}, state) do
    partitions = tuple_size(state)
    pids_by_partition = Utils.partition_pids(pids, partitions)
    do_send(message, pids_by_partition, state, 0, partitions)
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
        ^pid -> nil
        pid -> pid
      end)
      |> List.to_tuple

    {:noreply, state}
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
end
