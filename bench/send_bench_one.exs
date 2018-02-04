defmodule SendBenchOne do
  use Benchfella

  setup_all do
    pid = spawn_link &loop/0
    {:ok, pid}
  end

  defp loop() do
    receive do
      _ -> loop()
    end
  end

  bench "send enum each" do
    [bench_context] |> Enum.each(&send(&1, :hi))
  end

  bench "send list comp" do
    for pid <- [bench_context], do: send(pid, :hi)
  end

  bench "send one" do
    send(bench_context, :hi)
  end

  bench "send fast reducer" do
    send_r([bench_context], :hi)
  end

  defp send_r([], _msg), do: :ok
  defp send_r([pid | pids], msg) do
    send(pid, msg)
    send_r(pids, msg)
  end

end