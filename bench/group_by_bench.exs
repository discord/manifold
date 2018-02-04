defmodule GroupByBench do
  use Benchfella

  alias Manifold.Utils

  setup_all do
    pids = for _ <- 0..1000 do
      spawn_link &loop/0
    end

    {:ok, pids}
  end

  defp loop() do
    receive do
      _ -> loop()
    end
  end

  bench "group by" do
    bench_context |> Utils.group_by(&:erlang.phash2(&1, 48))
  end

  bench "partition_pids" do
    bench_context |> Utils.partition_pids(48)
  end


end