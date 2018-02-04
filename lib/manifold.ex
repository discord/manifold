defmodule Manifold do
  use Application

  alias Manifold.{Partitioner, Utils}

  ## OTP

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Spawn partitions based on number of schedlers (CPU cores).
    partitions = System.schedulers_online

    children = [
      Partitioner.child_spec(partitions, [name: Partitioner]),
    ]

    Supervisor.start_link children,
      strategy: :one_for_one,
      max_restarts: 10,
      name: __MODULE__.Supervisor
  end

  ## Client

  @spec send([pid | nil] | pid | nil, term) :: :ok
  def send([pid], message), do: send(pid, message)
  def send(pids, message) when is_list(pids) do
    grouped_by = Utils.group_by(fn
      nil -> nil
      pid -> node(pid)
    end)
    for {node, pids} <- grouped_by, node != nil, do: Partitioner.send({Partitioner, node}, pids, message)
  end
  def send(pid, message) when is_pid(pid), do: Partitioner.send({Partitioner, node(pid)}, [pid], message)
  def send(nil, message), do: :ok
end
