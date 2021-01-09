defmodule Todo.Server do
  @moduledoc """
  [Chapter 7 - Building a concurrent system > 7.2 Managing multiple to-do lists](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/34)

  Server cloned from chapter-6, but removed the server registration with a name
  and reintroduced the pid, so that it can be used to keep track of a pool of
  servers by TodoList name as per the coe in `Todo.Cache.server_process/2` and
  exemplified by the `Todo.Cache.Iex.TryIt.start_todo_list_servers_pool/1`.
  """

  ###########
  # CLIENT
  ###########

  def start() do
    GenServer.start(Todo.Server, nil)
  end

  def add_entry(pid, new_entry) do
    GenServer.cast(pid, {:add_entry, new_entry})
  end

  def update_entry(pid, entry_id, update_function) do
    GenServer.cast(pid, {:update_entry, entry_id, update_function})
  end

  def delete_entry(pid, entry_id) do
    GenServer.cast(pid, {:delete_entry, entry_id})
  end

  def entries(pid, date) do
    GenServer.call(pid, {:entries, date})
  end


  ###########
  # SERVER
  ###########

  use GenServer

  @impl GenServer
  def init(_init_params) do
    {:ok, Todo.List.new()}
  end

  @impl GenServer
  def handle_cast({:add_entry, new_entry}, todo_list) do
    {:noreply, Todo.List.add_entry(todo_list, new_entry)}
  end

  @impl GenServer
  def handle_cast({:update_entry, entry_id, update_function}, todo_list) do
    {:noreply, Todo.List.update_entry(todo_list, entry_id, update_function)}
  end

  @impl GenServer
  def handle_cast({:delete_entry, entry_id}, todo_list) do
    {:noreply, Todo.List.delete_entry(todo_list, entry_id)}
  end

  @impl GenServer
  def handle_call({:entries, date}, _info, todo_list) do
    {:reply, Todo.List.entries(todo_list, date), todo_list}
  end
end
