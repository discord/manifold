defmodule Manifold.Worker do
  use GenServer
  alias Manifold.Utils

  ## Client
  @spec start_link :: GenServer.on_start()
  def start_link, do: GenServer.start_link(__MODULE__, [])

  @spec send(pid, [pid], term, [Manifold.option()]) :: :ok
  def send(pid, pids, message, options), do: GenServer.cast(pid, {:send, pids, message, options})

  ## Server Callbacks
  @spec init([]) :: {:ok, nil}
  def init([]) do
    schedule_next_hibernate()
    {:ok, nil}
  end

  def handle_cast({:send, [pid], message, options}, nil) do
    message = Utils.unpack_message(message)
    send_opts = if options[:noconnect], do: [:noconnect], else: []
    send_opts = if options[:nosuspend], do: [:nosuspend | send_opts], else: send_opts
    Process.send(pid, message, send_opts)
    {:noreply, nil}
  end

  def handle_cast({:send, pids, message, options}, nil) do
    message = Utils.unpack_message(message)
    send_opts = if options[:noconnect], do: [:noconnect], else: []
    send_opts = if options[:nosuspend], do: [:nosuspend | send_opts], else: send_opts
    for pid <- pids, do: Process.send(pid, message, send_opts)
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
