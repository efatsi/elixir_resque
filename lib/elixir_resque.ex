defmodule ElixirResque do
  require IEx

  def init do
    Agent.start_link(fn -> Exredis.start end, name: :redis)
  end

  def mass_process do
    (1..5)
      |> Enum.each fn(x) ->
        IO.puts "Redis pull ##{x}"
        client
          |> Exredis.query(["LPOP", "caller"])
          |> act
      end
  end

  def act(:undefined) do
    IO.puts "nothing to pull from Redis"
  end

  def act(encoded_json) do
    encoded_json
      |> JSON.decode
      |> call_to_ruby
  end

  def call_to_ruby {:unexpected_token, results} do
    IO.puts "Could not JSON decode #{results}"
  end

  def call_to_ruby {:ok, hash_dict} do
    {:ok, id}    = Dict.fetch(hash_dict, "args")
    {:ok, klass} = Dict.fetch(hash_dict, "class")

    :timer.sleep(2000)

    IO.puts System.cmd("cd ../; rails runner '#{klass}.process(#{id})'")
  end

  def client do
    Agent.get(:redis, &(&1))
  end
end
