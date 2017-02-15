defmodule ManifoldTest do
  use ExUnit.Case
  doctest Manifold

  test "many pids" do
    me = self
    message = :hello
    pids = for _ <- 0..10000 do
      spawn fn ->
        receive do
          message -> send(me, {self, message})
        end
      end
    end
    Manifold.send(pids, message)
    for pid <- pids do
      assert_receive {^pid, ^message}
    end
  end
end
