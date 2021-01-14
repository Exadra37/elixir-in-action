defmodule Todo.Server do
  @moduledoc """
  [Chapter 7 - Building a concurrent system > 7.3 Persisting data](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/110)

  Server cloned from chapter-6, but removed the server registration with a name
  and reintroduced the pid, so that it can be used to keep track of a pool of
  servers by TodoList name as per the coe in `Todo.Cache.server_process/2` and
  exemplified by the `Todo.Cache.Iex.TryIt.start_todo_list_servers_pool/1`.
  """

  ###########
  # CLIENT
  ###########

  def start(%{} = params) do
    IO.puts("Starting Todo.Server.")
    GenServer.start(Todo.Server, params)
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
  def init(%{todo_list_name: todo_list_name}) do

    # The `init/1` function will block the client until the server is started,
    # thus any work we may want to do on it its better to run asynchronously,
    # by sending a message to the process itself, that will be handled then in
    # `handle_info/2`, therefore this function will return immediately. Even if
    # the work to be done is just some mileseconds of duration is still worth to
    # do it asynchronously, because when the server has thousands or millions of
    # clients wanting to start processes the throughput per second/minute will
    # severely affected.
    #
    # When the process is not registered with a name, then it's safe to send a
    # message to itself in order to initialize it asynchronously, because Erlang
    # just assigns the pid to the process after this `init/1` call returns,
    # therefore it's guaranteed that the message for `:async_init` will be the
    # first one in the mailbox of the process, therefore when the first client
    # request arrives it will be the second message in the mailbox, and messages
    # are processed always in order they arrive.
    #
    # Now, if the process has been started with a custom name or already
    # registered, then we don't have the same guarantee, because clients may
    # know the name of it and already had sent messages to it. The solution
    # for when we want to register the process with a custom name and have the
    # guarantee that `:async_init` is the first message in the mailbox of the
    # process is to only register the it after we send the `aync_init` message.
    # For example with `Process.register(self(), :some_name)`.
    send(self(), :async_init)

    {:ok, {todo_list_name, nil}}
  end

  @impl GenServer
  def handle_info(:async_init, {todo_list_name, nil}) do
    todo_list = Todo.Database.get(todo_list_name) || Todo.List.new()
    {:noreply, {todo_list_name, todo_list}}
  end

  @impl GenServer
  def handle_cast({:add_entry, new_entry}, {todo_list_name, todo_list}) do
    new_list = Todo.List.add_entry(todo_list, new_entry)
    Todo.Database.store(todo_list_name, new_list)
    {:noreply, {todo_list_name, new_list}}
  end

  @impl GenServer
  def handle_cast({:update_entry, entry_id, update_function}, {todo_list_name, todo_list}) do
    new_list = Todo.List.update_entry(todo_list, entry_id, update_function)
    Todo.Database.store(todo_list_name, new_list)
    {:noreply, {todo_list_name, new_list}}
  end

  @impl GenServer
  def handle_cast({:delete_entry, entry_id}, {todo_list_name, todo_list}) do
    new_list = Todo.List.delete_entry(todo_list, entry_id)
    Todo.Database.store(todo_list_name, new_list)
    {:noreply, {todo_list_name, new_list}}
  end

  @impl GenServer
  def handle_call({:entries, date}, _caller, {todo_list_name, _todo_list} = list) do
    new_list =
      todo_list_name
      |> Todo.Database.get()
      |> Todo.List.entries(date)

    {:reply, new_list, list}
  end
end
