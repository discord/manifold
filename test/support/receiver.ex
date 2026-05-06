defmodule Receiver do
  def hello_handler do
    receive do
      {:hello, sender} = message ->
        send(sender, {self(), message})
    end
  end

  def hello_reply_loop do
    receive do
      {:hello, sender, _n} = message ->
        send(sender, {self(), message})
    end

    hello_reply_loop()
  end

  def hello_noop_loop do
    receive do
      {:hello, _, _} ->
        :ok
    end

    hello_noop_loop()
  end
end
