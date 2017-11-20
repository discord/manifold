defmodule Manifold.Worker do
  use GenServer

  @gen_module Application.get_env(:manifold, :gen_module, GenServer)

  ## Client

  @spec start_link :: GenServer.on_start
  def start_link do
    GenServer.start_link(__MODULE__, [:ok])
  end

  @spec send(pid, [pid], term) :: :ok
  def send(pid, pids, message) do
    @gen_module.cast(pid, {:send, pids, message})
  end

  ## Server Callbacks

  def handle_cast({:send, pids, message}, state) do
    Enum.each(pids, &send(&1, message))
    {:noreply, state}
  end

  def handle_cast(_message, state) do
    {:noreply, state}
  end
end
