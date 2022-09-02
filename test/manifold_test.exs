defmodule ManifoldTest do
  use ExUnit.Case
  doctest Manifold

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
    [receiver] = LocalCluster.start_nodes(:manifold, 1, [
      files: [
        __ENV__.file
      ]
    ])

    me = self()
    message = {:hello, me}
    pids = for _ <- 0..10000 do
      Node.spawn_link(receiver, fn ->
        receive do
          {:hello, sender} -> send(sender, {self(), {:hello, sender}})
        end
      end)
    end
    Manifold.send(pids, message, send_mode: :offload)
    for pid <- pids do
      assert_receive {^pid, ^message},  1000
    end
  end

end
