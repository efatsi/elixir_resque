defmodule ElixirResque do
  require IEx

  def init do
    Agent.start_link(fn -> Exredis.start end, name: :redis)
  end

  def act do
    client
    |> Exredis.query(["LPOP", "caller"])
    |> JSON.decode
    |> call_to_ruby
  end

  def call_to_ruby {:ok, hash_dict} do
    {:ok, id}    = Dict.fetch(hash_dict, "args")
    {:ok, klass} = Dict.fetch(hash_dict, "class")

    :timer.sleep(2000)

    IO.puts System.cmd("cd ../; rails runner '#{klass}.process(#{id})'")
  end

  def call_to_ruby {:unexpected_token, results} do
    IO.puts "Could not JSON decode #{results}"
  end

  def client do
    Agent.get(:redis, &(&1))
  end
end
