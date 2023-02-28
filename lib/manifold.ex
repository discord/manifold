defmodule Manifold do
  use Application

  alias Manifold.Partitioner
  alias Manifold.Sender
  alias Manifold.Utils

  @type pack_mode :: :binary | :etf | nil

  @max_partitioners 32
  @partitioners min(Application.get_env(:manifold, :partitioners, 1), @max_partitioners)
  @workers_per_partitioner Application.get_env(:manifold, :workers_per_partitioner, System.schedulers_online)

  @max_senders 128
  @senders min(Application.get_env(:manifold, :senders, System.schedulers_online), @max_senders)

  ## OTP

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    partitioners =
      for partitioner_id <- 0..(@partitioners - 1) do
        Partitioner.child_spec(@workers_per_partitioner, name: partitioner_for(partitioner_id))
      end

    senders =
      for sender_id <- 0..(@senders - 1) do
        Sender.child_spec(name: sender_for(sender_id))
      end

    Supervisor.start_link(partitioners ++ senders,
      strategy: :one_for_one,
      max_restarts: 10,
      name: __MODULE__.Supervisor
    )
  end

  ## Client

  @spec valid_send_options?(Keyword.t()) :: boolean()
  def valid_send_options?(options) when is_list(options) do
    valid_options = [
      {:pack_mode, :binary},
      {:pack_mode, :etf},
      {:send_mode, :offload},
    ]

    # Keywords could have duplicate keys, in which case the first key wins.
    Keyword.keys(options)
    |> Enum.dedup()
    |> Enum.reduce(true, fn key, acc -> acc and {key, options[key]} in valid_options end)
  end

  def valid_send_options?(_options) do
    false
  end

  @spec send([pid | nil] | pid | nil, term, send_mode: :offload) :: :ok
  def send(pid, message, options \\ [])
  def send([pid], message, options), do: __MODULE__.send(pid, message, options)

  def send(pids, message, options) when is_list(pids) do
    case options[:send_mode] do
      :offload ->
        Sender.send(current_sender(), current_partitioner(), pids, message, options[:pack_mode])

      nil ->
        message = Utils.pack_message(options[:pack_mode], message)

        partitioner_name = current_partitioner()

        grouped_by =
          Utils.group_by(pids, fn
            nil -> nil
            pid -> node(pid)
          end)

        for {node, pids} <- grouped_by,
            node != nil,
            do: Partitioner.send({partitioner_name, node}, pids, message)

        :ok
    end
  end

  def send(pid, message, options) when is_pid(pid) do
    case options[:send_mode] do
      :offload ->
        # To maintain linearizability guaranteed by send/2, we have to send
        # it to the sender process, even for a single receiving pid.
        #
        # Since we know we are only sending to a single pid, there's no
        # performance benefit to packing the message, so we will always send as
        # raw etf.
        Sender.send(current_sender(), current_partitioner(), [pid], message, :etf)

      nil ->
        Partitioner.send({current_partitioner(), node(pid)}, [pid], message)
    end
  end

  def send(nil, _message, _options), do: :ok

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

  def set_sender_key(key) do
    sender =
      key
      |> Utils.hash()
      |> rem(@senders)
      |> sender_for()

    Process.put(:manifold_sender, sender)
  end

  def current_sender() do
    case Process.get(:manifold_sender) do
      nil ->
        sender_for(self())

      sender ->
        sender
    end
  end

  def sender_for(pid) when is_pid(pid) do
    pid
    |> Utils.partition_for(@senders)
    |> sender_for
  end

  for sender_id <- 0..(@max_senders - 1) do
    def sender_for(unquote(sender_id)) do
      unquote(:"Manifold.Sender_#{sender_id}")
    end
  end
end
