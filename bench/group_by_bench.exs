defmodule GroupByBench do
  use Benchfella

  alias Manifold.Utils

  setup_all do
    pids = for _ <- 0..5000, do: spawn_link &loop/0
    {:ok, pids}
  end

  defp loop() do
    receive do
      _ -> loop()
    end
  end

  bench "group by 48" do
    bench_context
    |> Utils.group_by(&:erlang.phash2(&1, 48))
  end

  bench "partition_pids 48" do
    bench_context
    |> Utils.partition_pids(48)
  end

  bench "group by 24" do
    bench_context
    |> Utils.group_by(&:erlang.phash2(&1, 24))
  end

  bench "partition_pids 24" do
    bench_context
    |> Utils.partition_pids(24)
  end

  bench "group by 8" do
    bench_context
    |> Utils.group_by(&:erlang.phash2(&1, 8))
  end

  bench "partition_pids 8" do
    bench_context
    |> Utils.partition_pids(8)
  end


end