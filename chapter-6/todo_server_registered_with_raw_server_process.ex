defmodule TodoServer do
  @moduledoc """
  [Chapter 6 - Generic Server Processes > 6.1 Building a generic server process > 6.1.5 Exercise: refactoring the to-do server](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-6/68)

  A server to show how registered processes can be used to maintain complex
  state. The main difference the other TodoServer is that in this one the client
  doesn't need to pass the TodoServer pid each time it invokes an operation on
  it. The TodoServer is now registered with an unique name for the local
  instance of the BEAM, like :todo_server, thus each time the Client interface
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
      true

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

  def start do
    ServerProcess.start(TodoServer)
    |> Process.register(:todo_server)
  end

  def add_entry(new_entry) do
    ServerProcess.cast(:todo_server, {:add_entry, new_entry})
  end

  def update_entry(entry_id, update_function) do
    ServerProcess.cast(:todo_server, {:update_entry, entry_id, update_function})
  end

  def delete_entry(entry_id) do
    ServerProcess.cast(:todo_server, {:delete_entry, entry_id})
  end

  def entries(date) do
    ServerProcess.call(:todo_server, {:entries, date})
  end


  ###########
  # SERVER
  ###########

  def init() do
    TodoList.new()
  end

  def handle_cast({:add_entry, new_entry}, todo_list) do
    TodoList.add_entry(todo_list, new_entry)
  end

  def handle_cast({:update_entry, entry_id, update_function}, todo_list) do
    TodoList.update_entry(todo_list, entry_id, update_function)
  end

  def handle_cast({:delete_entry, entry_id}, todo_list) do
    TodoList.delete_entry(todo_list, entry_id)
  end

  def handle_call({:entries, date}, todo_list) do
    {TodoList.entries(todo_list, date), todo_list}
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


defmodule ServerProcess do
  @moduledoc """
  [Chapter 6 - Generic Server Processes > 6.1 Building a generic server process](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-6/7)

  ServerProcess module to implement a generic server abstraction that can then
  be used by other modules to implement a server behaviour without the need to
  go through all the ceremony involved in creating one.

  Check the KeyValueStore in this same file that implements the ServerProcess
  abstraction to build the key value store.

  """

  ###########
  # CLIENT
  ###########

  @doc """
  Start the sever and returns it PID.

  ## Examples

      iex> pid = ServerProcess.start KeyValueStore
      #PID<0.182.0>

  """
  def start(callback_module) do
    spawn(
      fn ->
        initial_state = callback_module.init()
        _loop(callback_module, initial_state)
      end
    )
  end

  @doc """
  Synchronous call to the server.

  The client sends a request to the server and it will need to wait until it
  receives the response from the server. If the server doesn't respond in 5
  seconds a time-out error is returned, and the server dies due to the raised
  exception.

  ## Examples

      iex> pid = ServerProcess.start KeyValueStore
      #PID<0.182.0>

      iex> ServerProcess.call pid, :invalid_request

      23:34:01.198 [error] Process #PID<0.182.0> raised an exception
      ** (FunctionClauseError) no function clause matching in KeyValueStore.handle_call/2
          chapter-6/server_process.ex:96: KeyValueStore.handle_call(:invalid_request, %{})
          chapter-6/server_process.ex:52: ServerProcess._loop/2
      {:error, :timeout}

  """
  def call(server_pid, request) do
    send(server_pid, {:call, request, self()})

    receive do
      {:response, response} ->
        response
    after
      5000 ->
        {:error, :timeout}
    end
  end

  @doc """
  Asynchronous call to the server, also known as fire and forget call.

  The client sends a request to the server and doesn't wait for the response,
  and code execution continues immediately to the next line.

  So, if the server doesn't process successfully the request the client will not
  know, but if is an exception is raised the server will die, but this time
  without the time-out error we saw in `call/2`.

  ## Examples

      iex> pid = ServerProcess.start KeyValueStore
      #PID<0.194.0>

      iex> ServerProcess.cast pid, :invalid_request
      :ok

      iex>
      23:43:21.381 [error] Process #PID<0.194.0> raised an exception
      ** (FunctionClauseError) no function clause matching in KeyValueStore.handle_cast/2
          chapter-6/server_process.ex:104: KeyValueStore.handle_cast(:invalid_request, %{})
          chapter-6/server_process.ex:57: ServerProcess._loop/2

  """
  def cast(server_pid, request) do
    send(server_pid, {:cast, request})
    :ok
  end


  ###########
  # SERVER
  ###########

  defp _loop(callback_module, current_state) do
    receive do
      {:call, request, caller} ->
        {response, new_state} = callback_module.handle_call(request, current_state)
        send(caller, {:response, response})
        _loop(callback_module, new_state)

      {:cast, request} ->
        new_state = callback_module.handle_cast(request, current_state)
        _loop(callback_module, new_state)

      request ->
        IO.inspect({:invalid_request, request})
        _loop(callback_module, current_state)
    end
  end

end
