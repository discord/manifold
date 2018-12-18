defmodule Manifold.Worker do
  use GenServer
  alias Manifold.Utils

  ## Client
  @spec start_link :: GenServer.on_start
  def start_link, do: GenServer.start_link(__MODULE__, [])

  @spec send(pid, [pid], term) :: :ok
  def send(pid, pids, message), do: GenServer.cast(pid, {:send, pids, message})

  ## Server Callbacks
  @spec init([]) :: {:ok, nil}
  def init([]) do
    schedule_next_hibernate()
    {:ok, nil}
  end

  def handle_cast({:send, [pid], message}, nil) do
    send(pid, message)
    {:noreply, nil}
  end

  def handle_cast({:send, pids, message}, nil) do
    for pid <- pids, do: send(pid, message)
    {:noreply, nil}
  end

  def handle_cast(_message, nil), do: {:noreply, nil}

  def handle_info(:hibernate, nil) do
    schedule_next_hibernate()
    {:noreply, nil, :hibernate}
  end

  defp schedule_next_hibernate() do
    Process.send_after(self(), :hibernate, Utils.next_hibernate_delay())
  end
end
