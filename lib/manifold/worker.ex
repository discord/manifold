defmodule Manifold.Worker do
  use GenServer

  ## Client
  @spec start_link :: GenServer.on_start
  def start_link, do: GenServer.start_link(__MODULE__, [])

  @spec send(pid, [pid], term) :: :ok
  def send(pid, pids, message), do: GenServer.cast(pid, {:send, pids, message})

  ## Server Callbacks
  @spec init([]) :: {:ok, nil}
  def init([]), do: {:ok, nil}

  def handle_cast({:send, [pid], message}, nil) do
    send(pid, message)
    {:noreply, nil}
  end

  def handle_cast({:send, pids, message}, nil) do
    for pid <- pids, do: send(pid, message)
    {:noreply, nil}
  end

  def handle_cast(_message, nil), do: {:noreply, nil}
end
