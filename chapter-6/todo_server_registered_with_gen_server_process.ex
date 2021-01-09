defmodule TodoServer do
  @moduledoc """
  [Chapter 6 - Generic Server Processes > 6.2 Using GenServer > Exercise: GenServer-powered to-do server](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-6/182)

  Reimplementing the Todo Server with the buil-in Elixir GenServer abstraction,
  instead of the previous custom one, the ServerProcess.

  A server to show how registered processes can be used to maintain complex
  state. The main difference the other TodoServer is that in this one the client
  doesn't need to pass the TodoServer pid each time it invokes an operation on
  it. The TodoServer is now registered with an unique name for the local
  instance of the BEAM, like __MODULE__, thus each time the Client interface
  needs to dispatch a message to the TodoServer it doesn't need to know it's pid.
  This removes the need for the client to keep track of the pid, thus making the
  interface for the TodoServer much more simple and practical.

  The TodoServer will make possible to use and manipulated the TodoList
  concurrently, and maintain its state after each interaction, while at the same
  time the TodoList will keep its functional approach, where data is transformed
  and kept immutable.

  The TodoServer will also ensure that each access to the TodoList is processed
  in the order its received.

  ## Examples

      iex> TodoServer.start()
      {:ok, #PID<0.249.0>}

      iex> TodoServer.add_entry(%{date: ~D[2018-12-19], title: "Dentist"})
      :ok

      iex> TodoServer.add_entry(%{date: ~D[2018-12-20], title: "Shopping"})
      :ok

      iex> TodoServer.add_entry(%{date: ~D[2018-12-19], title: "Movies"})
      :ok

      iex> TodoServer.entries(~D[2018-12-19])
      [
        %{date: ~D[2018-12-19], id: 1, title: "Dentist"},
        %{date: ~D[2018-12-19], id: 3, title: "Movies"}
      ]

      iex> TodoServer.entries(~D[2018-12-20])
      [%{date: ~D[2018-12-20], id: 2, title: "Shopping"}]

      iex> TodoServer.delete_entry 2
      :ok

      iex> TodoServer.entries(~D[2018-12-20])
      []

      iex> TodoServer.update_entry 3, &Map.put(&1, :date, ~D[2018-12-20])
      :ok

      iex> TodoServer.entries(~D[2018-12-20])
      [%{date: ~D[2018-12-20], id: 3, title: "Movies"}]

      iex> TodoServer.entries(~D[2018-12-19])
      [%{date: ~D[2018-12-19], id: 1, title: "Dentist"}]

  """

  ###########
  # CLIENT
  ###########

  @server_name __MODULE__

  def start do
    GenServer.start(TodoServer, nil, name: @server_name)
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
    {:ok, TodoList.new()}
  end

  @impl GenServer
  def handle_cast({:add_entry, new_entry}, todo_list) do
    {:noreply, TodoList.add_entry(todo_list, new_entry)}
  end

  @impl GenServer
  def handle_cast({:update_entry, entry_id, update_function}, todo_list) do
    {:noreply, TodoList.update_entry(todo_list, entry_id, update_function)}
  end

  @impl GenServer
  def handle_cast({:delete_entry, entry_id}, todo_list) do
    {:noreply, TodoList.delete_entry(todo_list, entry_id)}
  end

  @impl GenServer
  def handle_call({:entries, date}, _info, todo_list) do
    {:reply, TodoList.entries(todo_list, date), todo_list}
  end
end


defmodule TodoList do
  @moduledoc """
  When used directly the TodoList is using the functional approach of
  transforming immutable data, because it returns a new copy of itself with the
  requested operation performed on it, thus not modifying in place the received
  data, as done in object orientated approaches.

  When used through the TodoServer the TodoList keeps the functional approach,
  but the TodoServer is the one that makes possible to change its state, like if
  it was a mutable data structure, when in fact its immutable.

  """
  defstruct auto_id: 1, entries: %{}

  def new(entries \\ []) do
    Enum.reduce(
      entries,
      %TodoList{},
      &add_entry(&2, &1)
    )
  end

  def add_entry(todo_list, entry) do
    entry = Map.put(entry, :id, todo_list.auto_id)
    new_entries = Map.put(todo_list.entries, todo_list.auto_id, entry)

    %TodoList{todo_list |
      entries: new_entries,
      auto_id: todo_list.auto_id + 1
    }
  end

  def entries(todo_list, date) do
    todo_list.entries
    |> Stream.filter(fn {_, entry} -> entry.date == date end)
    |> Enum.map(fn {_, entry} -> entry end)
  end

  def update_entry(todo_list, %{} = new_entry) do
    update_entry(todo_list, new_entry.id, fn _ -> new_entry end)
  end

  def update_entry(todo_list, entry_id, updater_fun) do
    case Map.fetch(todo_list.entries, entry_id) do
      :error ->
        todo_list

      {:ok, old_entry} ->
        new_entry = updater_fun.(old_entry)
        new_entries = Map.put(todo_list.entries, new_entry.id, new_entry)
        %TodoList{todo_list | entries: new_entries}
    end
  end

  def delete_entry(todo_list, entry_id) do
    %TodoList{todo_list | entries: Map.delete(todo_list.entries, entry_id)}
  end
end
