defmodule WorkerSendOneBenches do
  use Benchfella

  alias Manifold.Utils

  defmodule Worker do
    use GenServer

    ## Client
    @spec start_link :: GenServer.on_start
    def start_link, do: GenServer.start_link(__MODULE__, [])

    @spec send(pid, [pid], term) :: :ok
    def send(pid, pids, message), do: GenServer.cast(pid, {:send, pids, message})

    ## Server Callbacks
    @spec init([]) :: {:ok, nil}
    def init([]), do: {:ok, nil}

    def handle_cast({:send, _pids, _message}, nil) do
      {:noreply, nil}
    end

    def handle_cast(_message, nil), do: {:noreply, nil}
  end


  setup_all do
    workers = (for _ <- 0..47, do: Worker.start_link() |> elem(1)) |> List.to_tuple
    pids = [spawn_link &loop/0]

    pids_by_partition = Utils.partition_pids(pids, tuple_size(workers))
    pids_by_partition_map = Utils.group_by(pids, &Utils.partition_for(&1, tuple_size(workers)))

    {:ok, {workers, pids_by_partition, pids_by_partition_map}}
  end

  defp loop() do
    receive do
      _ -> loop()
    end
  end

  bench "enum reduce send" do
    {workers, _, pids_by_partition_map} = bench_context
    Enum.reduce(pids_by_partition_map, workers, fn ({partition, pids}, state) ->
      {worker_pid, state} = get_worker_pid(partition, state)
      Worker.send(worker_pid, pids, :hi)
      state
    end)
  end

  bench "do_send send" do
    {workers, pids_by_partition, _} = bench_context
    do_send(:hi, pids_by_partition, workers, 0, tuple_size(pids_by_partition))
  end


  defp get_worker_pid(partition, state) do
    case elem(state, partition) do
      nil ->
        {:ok, pid} = Worker.start_link()
        {pid, put_elem(state, partition, pid)}
      pid ->
        {pid, state}
    end
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