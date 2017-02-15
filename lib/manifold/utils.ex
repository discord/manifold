defmodule Manifold.Utils do
  @type groups :: %{any => [pid]}
  @type key_fun :: (any -> any)

  @doc """
  A faster version of Enum.group_by with less bells and whistles.
  """
  @spec group_by([pid], key_fun) :: groups
  def group_by(pids, key_fun), do: group_by(pids, key_fun, Map.new)

  @spec group_by([pid], key_fun, groups) :: groups
  def group_by([pid|pids], key_fun, groups) do
    key = key_fun.(pid)
    group = Map.get(groups, key) || []
    group_by(pids, key_fun, Map.put(groups, key, [pid|group]))
  end
  def group_by([], _key_fun, groups), do: groups
end
