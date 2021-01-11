defmodule Todo.DatabaseWorker do
  @moduledoc """
  [Chapter 7 - Building a concurrent system > 7.3 Persisting data > 7.3.5 Exercise: pooling and synchronizing](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/192)

  """

  @callback_module __MODULE__

  ###########
  # CLIENT
  ###########

  def start(%{} = params) do
    GenServer.start(@callback_module, params)
  end

  def store(pid, key, data) do
    GenServer.cast(pid, {:store, key, data})
  end

  def get(pid, key) do
    GenServer.call(pid, {:get, key})
  end


  ###########
  # SERVER
  ###########

  use GenServer

  @impl GenServer
  def init(%{database_folder: database_folder} = params) do
    state = %{params: params}

    File.mkdir_p!(database_folder)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:store, key, data}, state) do
    key
    |> _file_name(state)
    |> File.write!(:erlang.term_to_binary(data))

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get, key}, _caller, state) do
    case File.read(_file_name(key, state)) do
      {:ok, contents} ->
        {:reply, :erlang.binary_to_term(contents), state}

      _ ->
        {:reply, nil, state}
    end
  end

  defp _file_name(key, %{params: %{database_folder: database_folder}} = _state) do
    Path.join(database_folder, to_string(key))
  end
end
