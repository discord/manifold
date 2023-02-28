defmodule SendVsEncodeBench do
  use Benchfella

  defmodule Receiver do
    def loop do
      receive do
        _ ->
          loop()
      end
    end
  end

  setup_all do
    pid = spawn(Receiver, :loop, [])
    {:ok, pid}
  end

  bench "sending message", [message: gen_message()] do
    send(bench_context, message)
  end

  bench "encoding message", [message: gen_message()] do
    :erlang.term_to_binary(message)
  end

  defp gen_message() do
    Map.new(1..1_000_000, fn item -> {item, :erlang.unique_integer()} end)
  end
end
