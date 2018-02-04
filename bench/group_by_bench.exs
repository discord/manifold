defmodule GroupByBench do
  use Benchfella

  alias Manifold.Utils

  setup_all do
    pids = for _ <- 0..1000 do
      spawn_link &loop/0
    end

    {:ok, _} = Manifold.Partitioner.start_link(8, name: Manifold.Partitioner)
    {:ok, pids}
  end

  defp loop() do
    receive do
      _ -> loop()
    end
  end

  bench "group by with tuple" do
    bench_context |> Utils.partition_pids(48)
  end

  bench "manifold send" do
    Manifold.send(bench_context, :hello)
  end


end