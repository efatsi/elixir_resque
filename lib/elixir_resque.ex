defmodule ElixirResque do
  use GenServer
  require IEx

  def init do
    Agent.start_link(fn -> Exredis.start end, name: :redis)

    {:ok, pid} = GenServer.start_link(ElixirResque, [])
    Agent.start_link(fn -> pid end, name: :server)
  end

  # GOALS:
  # pull from redis
  # if nothing returned, stop
  # if something returned, queue up thing, repeat
  def redis_pull do
    redis
      |> Exredis.query(["LPOP", "caller"])
      |> process
  end

  def process(:undefined) do
    IO.puts "nothing left in the Redis queue!"
    GenServer.call server, :retrieve
  end

  def process(encoded_json) do
    IO.puts "Pulling #{encoded_json} from Redis"
    GenServer.cast server, fn ->
      encoded_json
        |> JSON.decode
        |> call_to_ruby
      end

    redis_pull
  end

  def call_to_ruby {:unexpected_token, results} do
    IO.puts "Could not JSON decode #{results}"
  end

  def call_to_ruby {:ok, hash_dict} do
    {:ok, id}    = Dict.fetch(hash_dict, "args")
    {:ok, klass} = Dict.fetch(hash_dict, "class")

    :timer.sleep(2000)
    System.cmd("cd ../; rails runner '#{klass}.process(#{id})'")
  end

  def redis do
    Agent.get(:redis, &(&1))
  end

  def server do
    Agent.get(:server, &(&1))
  end


  # GenServer things

  def handle_call(:retrieve, _from, list) do
    reports = list |> Enum.map(fn(task) -> Task.await(task) end)
    {:reply, reports, []}
  end

  def handle_cast(task, list) do
    {:noreply, [Task.async(task) | list]}
  end
end
