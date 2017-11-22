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
    {:ok, Tuple.duplicate(nil, partitions)}
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
    state = pids
      |> Utils.group_by(&:erlang.phash2(&1, tuple_size(state)))
      |> Enum.reduce(state, fn ({partition, pids}, state) ->
        {worker_pid, state} = get_worker_pid(partition, state)
        Worker.send(worker_pid, pids, message)
        state
      end)
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

  ## Private

  defp get_worker_pid(partition, state) do
    case elem(state, partition) do
      nil ->
        {:ok, pid} = Worker.start_link
        {pid, put_elem(state, partition, pid)}
      pid ->
        {pid, state}
    end
  end
end
