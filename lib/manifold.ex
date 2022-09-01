defmodule Manifold do
  use Application

  alias Manifold.{Partitioner, Utils}

  @max_partitioners 32
  @partitioners min(Application.get_env(:manifold, :partitioners, 1), @max_partitioners)
  @workers_per_partitioner Application.get_env(:manifold, :workers_per_partitioner, System.schedulers_online)

  ## OTP

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = for partitioner_id <- 0..(@partitioners - 1) do
      Partitioner.child_spec(@workers_per_partitioner, [name: partitioner_for(partitioner_id)])
    end

    Supervisor.start_link children,
      strategy: :one_for_one,
      max_restarts: 10,
      name: __MODULE__.Supervisor
  end

  ## Client

  @spec send([pid | nil] | pid | nil, term, :offload | :no_offload) :: :ok
  def send(pid, message, send_mode \\ :no_offload)
  def send([pid], message, send_mode), do: __MODULE__.send(pid, message, send_mode)
  def send(pids, message, :no_offload) when is_list(pids) do
    partitioner_name = current_partitioner()
    grouped_by = Utils.group_by(pids, fn
      nil -> nil
      pid -> node(pid)
    end)
    for {node, pids} <- grouped_by, node != nil, do: Partitioner.send({partitioner_name, node}, pids, message)
    :ok
  end
  def send(pid, message, :no_offload) when is_pid(pid), do: Partitioner.send({current_partitioner(), node(pid)}, [pid], message)
  def send(pids, message, :offload) when is_list(pids) do
    Partitioner.offload_send(current_partitioner(), pids, message)
  end
  def send(pid, message, :offload) when is_pid(pid) do
    Partitioner.offload_send(current_partitioner(), [pid], message)
  end
  def send(nil, _message, _send_mode), do: :ok

  def set_partitioner_key(key) do
    partitioner = key
    |> Utils.hash()
    |> rem(@partitioners)
    |> partitioner_for()

    Process.put(:manifold_partitioner, partitioner)
  end

  def current_partitioner() do
    case Process.get(:manifold_partitioner) do
      nil ->
        partitioner_for(self())
      partitioner ->
        partitioner
    end
  end

  def partitioner_for(pid) when is_pid(pid) do
    pid
    |> Utils.partition_for(@partitioners)
    |> partitioner_for
  end

  # The 0th partitioner does not have a number in it's process name for backwards compatibility
  # purposes.
  def partitioner_for(0), do: Manifold.Partitioner
  for partitioner_id <- (1..@max_partitioners - 1) do
    def partitioner_for(unquote(partitioner_id)) do
      unquote(:"Manifold.Partitioner_#{partitioner_id}")
    end
  end
end
