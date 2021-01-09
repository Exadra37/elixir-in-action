defmodule Todo.Server do
  @moduledoc """
  [Chapter 7 - Building a concurrent system > 7.1 Working with the mix project](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/8)

  Reimplementing the Todo Server with the buil-in Elixir GenServer abstraction,
  instead of the previous custom one, the ServerProcess.

  A server to show how registered processes can be used to maintain complex
  state. The main difference the other Todo.Server is that in this one the client
  doesn't need to pass the Todo.Server pid each time it invokes an operation on
  it. The Todo.Server is now registered with an unique name for the local
  instance of the BEAM, like __MODULE__, thus each time the Client interface
  needs to dispatch a message to the Todo.Server it doesn't need to know it's pid.
  This removes the need for the client to keep track of the pid, thus making the
  interface for the Todo.Server much more simple and practical.

  The Todo.Server will make possible to use and manipulated the Todo.List
  concurrently, and maintain its state after each interaction, while at the same
  time the Todo.List will keep its functional approach, where data is transformed
  and kept immutable.

  The Todo.Server will also ensure that each access to the Todo.List is processed
  in the order its received.

  ## Examples

      iex> Todo.Server.start()
      {:ok, #PID<0.249.0>}

      iex> Todo.Server.add_entry(%{date: ~D[2018-12-19], title: "Dentist"})
      :ok

      iex> Todo.Server.add_entry(%{date: ~D[2018-12-20], title: "Shopping"})
      :ok

      iex> Todo.Server.add_entry(%{date: ~D[2018-12-19], title: "Movies"})
      :ok

      iex> Todo.Server.entries(~D[2018-12-19])
      [
        %{date: ~D[2018-12-19], id: 1, title: "Dentist"},
        %{date: ~D[2018-12-19], id: 3, title: "Movies"}
      ]

      iex> Todo.Server.entries(~D[2018-12-20])
      [%{date: ~D[2018-12-20], id: 2, title: "Shopping"}]

      iex> Todo.Server.delete_entry 2
      :ok

      iex> Todo.Server.entries(~D[2018-12-20])
      []

      iex> Todo.Server.update_entry 3, &Map.put(&1, :date, ~D[2018-12-20])
      :ok

      iex> Todo.Server.entries(~D[2018-12-20])
      [%{date: ~D[2018-12-20], id: 3, title: "Movies"}]

      iex> Todo.Server.entries(~D[2018-12-19])
      [%{date: ~D[2018-12-19], id: 1, title: "Dentist"}]

  """

  ###########
  # CLIENT
  ###########

  @server_name __MODULE__

  def start do
    GenServer.start(Todo.Server, nil, name: @server_name)
  end

  def add_entry(new_entry) do
    GenServer.cast(@server_name, {:add_entry, new_entry})
  end

  def update_entry(entry_id, update_function) do
    GenServer.cast(@server_name, {:update_entry, entry_id, update_function})
  end

  def delete_entry(entry_id) do
    GenServer.cast(@server_name, {:delete_entry, entry_id})
  end

  def entries(date) do
    GenServer.call(@server_name, {:entries, date})
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
