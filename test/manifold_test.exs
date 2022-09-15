defmodule ManifoldTest do
  use ExUnit.Case
  doctest Manifold

  test "valid_send_options?" do
    assert Manifold.valid_send_options?([])
    assert Manifold.valid_send_options?(send_mode: :offload)
    assert Manifold.valid_send_options?(send_mode: :offload, send_mode: :bad)

    assert !Manifold.valid_send_options?(send_mode: :bad, send_mode: :offload)
    assert !Manifold.valid_send_options?(send_mode: :bad, send_mode: :offload)
    assert !Manifold.valid_send_options?(unknown: :bad)
    assert !Manifold.valid_send_options?(:junk)
    assert !Manifold.valid_send_options?({:junk, :junk})
  end

  test "many pids" do
    me = self()
    message = :hello
    pids = for _ <- 0..10000 do
      spawn_link fn ->
        receive do
          message -> send(me, {self(), message})
        end
      end
    end
    Manifold.send(pids, message)
    for pid <- pids do
      assert_receive {^pid, ^message},  1000
    end
  end

  test "send to list of one" do
    me = self()
    message = :hello
    pid = spawn_link fn ->
      receive do
        message -> send(me, message)
      end
    end
    Manifold.send([pid], message)
    assert_receive ^message
  end

  test "send to one" do
    me = self()
    message = :hello
    pid = spawn_link fn ->
      receive do
        message -> send(me, message)
      end
    end
    Manifold.send(pid, message)
    assert_receive ^message
  end

  test "send to nil" do
    assert Manifold.send([nil], :hi) == :ok
    assert Manifold.send(nil, :hi) == :ok
  end

  test "send with nil in list wont blow up" do
    me = self()
    message = :hello
    pid = spawn_link fn ->
      receive do
        message -> send(me, message)
      end
    end
    Manifold.send([nil, pid, nil], message)
    assert_receive ^message
  end

  test "send with pinned process" do
    me = self()
    message = :hello
    pid = spawn_link fn ->
      receive do
        message -> send(me, message)
      end
      receive do
        message -> send(me, message)
      end
    end
    assert Process.get(:manifold_partitioner) == nil
    Manifold.set_partitioner_key("hello")
    assert Process.get(:manifold_partitioner) == Manifold.Partitioner

    Manifold.send([nil, pid, nil], message)
    Manifold.send(pid, message)
    assert_receive ^message
    assert_receive ^message
  end

  test "many pids using :offload" do
    [receiver] =
      LocalCluster.start_nodes(:manifold, 1,
        files: [
          __ENV__.file
        ]
      )

    me = self()
    message = {:hello, me}

    pids =
      for _ <- 0..10000 do
        Node.spawn_link(receiver, fn ->
          receive do
            {:hello, sender} -> send(sender, {self(), {:hello, sender}})
          end
        end)
      end

    Manifold.send(pids, message, send_mode: :offload)

    for pid <- pids do
      assert_receive {^pid, ^message}, 1000
    end
  end

  defmacro assert_next_receive(pattern, timeout \\ 100) do
    quote do
      receive do
        message ->
          assert unquote(pattern) = message
      after
        unquote(timeout) ->
          raise "timeout"
      end
    end
  end

  test "send/2 linearization guarantees with :offload" do
    [receiver] =
      LocalCluster.start_nodes(:manifold, 1,
        files: [
          __ENV__.file
        ]
      )

    # Set up several receiving pids, but only the first pid echos
    # the message back to the sender...
    pids =
      for n <- 0..2 do
        loop =
          if n == 0 do
            fn f ->
              receive do
                {:hello, sender, n} ->
                  send(sender, {self(), {:hello, sender, n}})
                  f.(f)
              end
            end
          else
            fn f ->
              receive do
                {:hello, _sender, _n} ->
                  f.(f)
              end
            end
          end

        Node.spawn_link(receiver, fn -> loop.(loop) end)
      end

    me = self()
    [pid | _] = pids

    # Fire off a bunch of messages, with some sent only to the
    # first receiving pid, while others sent to all pids.
    for n <- 0..1000 do
      message = {:hello, me, n}

      if rem(n, 2) == 0 do
        Manifold.send(pid, message, send_mode: :offload)
      else
        Manifold.send(pids, message, send_mode: :offload)
      end
    end

    # Expect the messages to be echoed back from the first
    # receiving pid in order.
    for n <- 0..1000 do
      message = {:hello, me, n}
      assert_next_receive({^pid, ^message}, 1000)
    end
  end
end
