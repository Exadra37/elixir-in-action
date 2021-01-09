defmodule KeyValueStore do
  @moduledoc """
  [Chapter 6 - Generic Server Processes > 6.2 Using GenServer](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-6/71)

  Key Value Store module to show how to use the built-in Elixir GenServer
  abstraction.

  ## Example

      iex> {:ok, pid} = KeyValueStore.start
      {:ok, #PID<0.525.0>}

      iex> KeyValueStore.put pid, :key, :value
      :ok

      iex> KeyValueStore.put pid, :key2, :value2
      :ok

      iex> KeyValueStore.get pid, :key2
      :value2

      iex> KeyValueStore.get pid, :key
      :value

      iex> KeyValueStore.get pid, :key1
      nil

  """

  use GenServer

  ###########
  # CLIENT
  ###########

  def start() do
    GenServer.start(KeyValueStore, nil)
  end

  def put(pid, key, value) do
    GenServer.cast(pid, {:put, key, value})
  end

  def get(pid, key) do
    GenServer.call(pid, {:get, key})
  end


  #####################
  # SERVER CALLBACKS
  #####################

  @doc false
  @impl GenServer
  def init(_initial_args) do
    {:ok, _initial_state = %{}}
  end

  @doc false
  @impl GenServer
  def handle_call({:get, key}, _info, state) do
    {:reply, Map.get(state, key), state}
  end

  @doc false
  @impl GenServer
  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end
end
