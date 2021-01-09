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


defmodule KeyValueStore do
  @moduledoc """
  Key Value Store module to show how to use the ServerProcess abstraction.

  ## Example

      iex> pid = KeyValueStore.start
      #PID<0.254.0>

      iex> KeyValueStore.put pid, :key, :value
      :ok

      iex> KeyValueStore.put pid, :key2, :value2
      :ok

      iex> KeyValueStore.get pid, :key
      :value

      iex> KeyValueStore.get pid, :key2
      :value2

  """

  ###########
  # CLIENT
  ###########

  def start() do
    ServerProcess.start(KeyValueStore)
  end

  def put(pid, key, value) do
    ServerProcess.cast(pid, {:put, key, value})
  end

  def get(pid, key) do
    ServerProcess.call(pid, {:get, key})
  end


  #####################
  # SERVER CALLBACKS
  #####################

  @doc false
  def init() do
    %{}
  end

  @doc false
  def handle_call({:get, key}, state) do
    {Map.get(state, key), state}
  end

  @doc false
  def handle_cast({:put, key, value}, state) do
    Map.put(state, key, value)
  end
end
