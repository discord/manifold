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
      assert_receive {^pid, ^message}
    end
  end

  test "send one" do
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
end
