defmodule Manifold.Utils do
  @type groups :: %{any => [pid]}
  @type key_fun :: (any -> any)

  @doc """
  A faster version of Enum.group_by with less bells and whistles.
  """
  @spec group_by([pid], key_fun) :: groups
  def group_by(pids, key_fun), do: group_by(pids, key_fun, %{})

  @spec group_by([pid], key_fun, groups) :: groups
  defp group_by([pid | pids], key_fun, groups) do
    key = key_fun.(pid)
    group = Map.get(groups, key, [])
    group_by(pids, key_fun, Map.put(groups, key, [pid | group]))
  end
  defp group_by([], _key_fun, groups), do: groups

  @doc """
  Partitions a bunch of pids into a tuple, of lists of pids grouped by by the result of :erlang.pash2/2
  """
  @spec partition_pids([pid], integer) :: tuple
  def partition_pids(pids, partitions) do
    do_partition_pids(pids, partitions, Tuple.duplicate([], partitions))
  end

  defp do_partition_pids([pid | pids], partitions, pids_by_partition) do
    partition = partition_for(pid, partitions)
    pids_in_partition = elem(pids_by_partition, partition)
    do_partition_pids(pids, partitions, put_elem(pids_by_partition, partition, [pid | pids_in_partition]))
  end
  defp do_partition_pids([], _partitions, pids_by_partition), do: pids_by_partition

  @"""
  Computes the partition for a given pid using :erlang.phash2/2
  """
  @spec partition_for(pid, integer) :: integer
  def partition_for(pid, partitions) do
    :erlang.phash2(pid, partitions)
  end
end
