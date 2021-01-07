defmodule TodoServer do
  @moduledoc """
  [Chapter 5 - Concurrency primitives > 5.3 Stateful server processes > 5.3.4 Complex states](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-5/201)

  A server to show how processes can be used to maintain complex state.

  The TodoServer will make possible to use and manipulated the TodoList
  concurrently, and maintain its state after each interaction, while at the same
  time the TodoList will keep its functional approach, where data is transformed
  and kept immutable.

  The TodoServer will also ensure that each access to the TodoList is processed
  in the order its received.

  ## Examples

      iex> todo_server = TodoServer.start()
      #PID<0.288.0>

      iex> TodoServer.add_entry(todo_server, %{date: ~D[2018-12-19], title: "Dentist"})
      {:add_entry, %{date: ~D[2018-12-19], title: "Dentist"}}

      iex> TodoServer.add_entry(todo_server, %{date: ~D[2018-12-20], title: "Shopping"})
      {:add_entry, %{date: ~D[2018-12-20], title: "Shopping"}}

      iex> TodoServer.add_entry(todo_server, %{date: ~D[2018-12-19], title: "Movies"})
      {:add_entry, %{date: ~D[2018-12-19], title: "Movies"}}

      iex> TodoServer.entries(todo_server, ~D[2018-12-19])
      [
        %{date: ~D[2018-12-19], id: 1, title: "Dentist"},
        %{date: ~D[2018-12-19], id: 3, title: "Movies"}
      ]

      iex> TodoServer.entries(todo_server, ~D[2018-12-20])
      [%{date: ~D[2018-12-20], id: 2, title: "Shopping"}]

      iex> TodoServer.delete_entry todo_server, 2
      {:delete_entry, 2}

      iex> TodoServer.entries(todo_server, ~D[2018-12-20])
      []

      iex> TodoServer.update_entry todo_server, 3, &Map.put(&1, :date, ~D[2018-12-20])
      {:update_entry, 3, #Function<44.97283095/1 in :erl_eval.expr/5>}

      iex> TodoServer.entries(todo_server, ~D[2018-12-20])
      [%{date: ~D[2018-12-20], id: 3, title: "Movies"}]

      iex> TodoServer.entries(todo_server, ~D[2018-12-19])
      [%{date: ~D[2018-12-19], id: 1, title: "Dentist"}]

  """

  ###########
  # CLIENT
  ###########

  def start do
    spawn(fn -> _loop(TodoList.new()) end)
  end

  def add_entry(todo_server, new_entry) do
    send(todo_server, {:add_entry, new_entry})
  end

  def update_entry(todo_server, entry_id, update_function) do
    send(todo_server, {:update_entry, entry_id, update_function})
  end

  def delete_entry(todo_server, entry_id) do
    send(todo_server, {:delete_entry, entry_id})
  end

  def entries(todo_server, date) do
    send(todo_server, {:entries, self(), date})

    receive do
      {:todo_entries, entries} -> entries
    after
      5000 -> {:error, :timeout}
    end
  end


  ###########
  # SERVER
  ###########

  # Tail recursive function that keeps the server state, by calling itself with
  # the new value or the same unchanged value.
  defp _loop(todo_list) do
    new_todo_list =
      receive do
        # All the calls to process the message will delegate the operations to
        # the TodoList that will transform it and return a new structure, not
        # the same we sent to it, thus data is kept immutable in memory.
        message -> _process_message(todo_list, message)
      end

    # The tail recursive call to maintain state
    _loop(new_todo_list)
  end

  defp _process_message(todo_list, {:add_entry, new_entry}) do
    TodoList.add_entry(todo_list, new_entry)
  end

  defp _process_message(todo_list, {:update_entry, entry_id, update_function}) do
    TodoList.update_entry(todo_list, entry_id, update_function)
  end

  defp _process_message(todo_list, {:delete_entry, entry_id}) do
    TodoList.delete_entry(todo_list, entry_id)
  end

  defp _process_message(todo_list, {:entries, caller, date}) do
    send(caller, {:todo_entries, TodoList.entries(todo_list, date)})
    todo_list
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
