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
    GenServer.cast(@server_name, {:store, key, data})
  end

  def get(key) do
    GenServer.call(@server_name, {:get, key})
  end


  ###########
  # SERVER
  ###########

  @db_folder "./persist"

  use GenServer

  @impl GenServer
  def init(_params) do
    File.mkdir_p!(@db_folder)
    {:ok, nil}
  end

  @impl GenServer
  def handle_cast({:store, key, data}, state) do
    key
    |> _file_name()
    |> File.write!(:erlang.term_to_binary(data))

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get, key}, _caller, state) do
    case File.read(_file_name(key)) do
      {:ok, contents} ->
        {:reply, :erlang.binary_to_term(contents), state}

      _ ->
        {:reply, nil, state}
    end
  end

  defp _file_name(key) do
    Path.join(@db_folder, to_string(key))
  end
end
