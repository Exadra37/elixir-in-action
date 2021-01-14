defmodule Todo.Database do
  @moduledoc """
  [Chapter 7 - Building a concurrent system > 7.3 Persisting data > 7.3.5 Exercise: pooling and synchronizing](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/192)
  """

  @server_name __MODULE__
  @callback_module __MODULE__

  ###########
  # CLIENT
  ###########

  def start() do
    IO.puts("Starting Todo.Database.")
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

  # @POSSIBLE_SOLUTION: Solves the failed solution for `chapter-7/persistable_todo_cache_with_database_workers/lib/todo/database.ex`.
  #
  # Choosing a worker from the pool based on a numeric hash of the todo list
  # name guarantees that the todo list state is always managed by the same
  # worker, thus keeping the order of execution of all operations on it, no
  # matter how many clients are using it simultaneously, therefore eliminating
  # the race conditions we observed when spawning one-off workers on demand.
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
