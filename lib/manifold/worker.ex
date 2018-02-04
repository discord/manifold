defmodule Manifold.Worker do
  use GenServer

  ## Client

  @spec start_link :: GenServer.on_start
  def start_link do
    GenServer.start_link(__MODULE__, [:ok])
  end

  @spec send(pid, [pid], term) :: :ok
  def send(pid, pids, message) do
    GenServer.cast(pid, {:send, pids, message})
  end

  ## Server Callbacks
  def handle_cast({:send, [pid], message}, state) do
    send(pid, message)
    {:noreply, state}
  end
  def handle_cast({:send, pids, message}, state) do
    for pid <- pids, do: send(pid, message)
    {:noreply, state}
  end

  def handle_cast(_message, state) do
    {:noreply, state}
  end
end
