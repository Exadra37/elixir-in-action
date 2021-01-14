defmodule Todo.Cache do
  @moduledoc """
  [Chapter 8 - Fault-tolerance basics > 8.3 Supervisors](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-8/116)

  Implementing supervisors.

  ## Example

      iex> total_servers = 3

      iex> {:ok, cache} = Todo.Cache.start()

      iex> before_count = :erlang.system_info(:process_count)

      iex> Enum.each(
        1..total_servers,
        fn index ->
          Todo.Cache.server_process(cache, "to-do list" <> Integer.to_string(index))
        end
      )

      iex> after_count = :erlang.system_info(:process_count)

      iex> total_servers = after_count - before_count

  Tests available at `chapter-7/todo_cache/test/todo_cache_test.exs`.

  """

  ###########
  # CLIENT
  ###########

  @server_name __MODULE__
  @callback_module __MODULE__

  def start_link(_params) do
    IO.puts("Starting Todo.Cache.")
    GenServer.start_link(@callback_module, nil, name: @server_name)
  end

  def server_process(todo_list_name) do
    GenServer.call(@server_name, {:server_process, todo_list_name})
  end


  ###########
  # SERVER
  ###########

  use GenServer

  @impl GenServer
  def init(_init_params) do
    Todo.Database.start()
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:server_process, todo_list_name}, _caller, todo_servers) do
    case Map.fetch(todo_servers, todo_list_name) do
      {:ok, todo_server} ->
        {:reply, todo_server, todo_servers}

      :error ->
        {:ok, new_server} = Todo.Server.start(%{todo_list_name: todo_list_name})

        {
          :reply,
          new_server,
          Map.put(todo_servers, todo_list_name, new_server)
        }
      end
  end

end

defmodule Todo.Cache.Iex.TryIt do

  def start_todo_list_servers_pool(total_servers) do

    {:ok, cache} = Todo.Cache.start()

    before_count = :erlang.system_info(:process_count)
    IO.inspect(before_count, label: "PROCESS COUNT BEFORE")

    Enum.each(
      1..total_servers,
      fn index ->
        Todo.Cache.server_process(cache, "to-do list #{index}")
      end
    )

    after_count = :erlang.system_info(:process_count)
    IO.inspect(after_count, label: "PROCESS COUNT AFTER")
    IO.inspect(after_count - before_count, label: "PROCESS COUNT DIFF")
  end

  def run_cache_server(date \\ "2018-12-19", list_name \\ "iex_tryit_todo_list") do
    date = Date.from_iso8601!(date)

    {:ok, cache} = Todo.Cache.start()

    todo_list = Todo.Cache.server_process(cache, list_name)

    Enum.each(
      1..10,
      fn index ->
        Todo.Server.add_entry(todo_list, %{date: date, title: "task-#{index}"})
      end
    )

    Todo.Server.entries todo_list, date
  end

end
