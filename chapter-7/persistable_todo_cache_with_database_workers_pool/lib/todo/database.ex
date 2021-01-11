defmodule Todo.Database do
  @moduledoc """
  [Chapter 7 - Building a concurrent system > 7.3 Persisting data](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/110)
  """

  @server_name __MODULE__
  @callback_module __MODULE__

  ###########
  # CLIENT
  ###########

  def start() do
    GenServer.start(@callback_module, nil, name: @server_name)
  end

  def store(key, data) do
    GenServer.call(@server_name, {:choose_worker, key})
    |> GenServer.cast({:store, key, data})
  end

  def get(key) do
    GenServer.call(@server_name, {:choose_worker, key})
    |> GenServer.call({:get, key})
  end


  ###########
  # SERVER
  ###########

  @db_folder "./persist"

  use GenServer

  @impl GenServer
  def init(_params) do
    state = %{
      workers_pool: %{
        0 => _start_worker(),
        1 => _start_worker(),
        2 => _start_worker(),
      }
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:choose_worker, key}, _caller, %{workers_pool: workers_pool} = state) do

    # @LINK https://erlang.org/doc/man/erlang.html#phash2-2
    # This function will always hash the given `key` to the same numeric hash.
    # Having always the guarantee that the same `key` always returns the same
    # integer makes possible to always use the same worker for the same todo
    # list.
    numeric_hash = :erlang.phash2(key, 3)
    worker_pid = Map.get(workers_pool, numeric_hash)

    {:reply, worker_pid, state}
  end

  defp _start_worker() do
    {:ok, pid} = Todo.DatabaseWorker.start(%{database_folder: @db_folder})
    pid
  end
end
