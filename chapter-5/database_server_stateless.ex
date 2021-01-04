defmodule DatabaseServer do
  @moduledoc """
  [Chapter 5 - Concurrency primitives > 5.3 Stateful server processes > 5.3.1 Server processes](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-5/point-9298-124-124-0).

  This is an example for a dummy DatabaseServer, that will introduce the concept
  of server processes with pools to allow to run queries against a database
  concurrently, instead of the slower sequential approach.

  """

  @doc """
  This function will run in the caller process, aka the client, while the
  private `loop/0` function it starts will run in the server process, aka the
  one spawned with `spawn/1`.
  """
  def start() do
    spawn(&_loop/0)
  end

  @doc """
  In order to be able to use the Database server concurrently the clients needs
  to obtain a pool of spawned processes, where each one is running a database
  server connection, that is identified by the process PID.

  The pool list is returned duplicated in a tuple `{active_pool, initial_pool}`,
  where `active_pool` and `initial_pool` are the exact same list. The reason for
  this approach is to be able to transverse the pool list efficiently, while
  minimizing or eliminating the same database process to have queries running
  sequentially, aka waiting for the current query to finish its execution in
  order for the next one to start being executed.

  This approach addresses the fact that accessing the O(n) position in a list,
  that is not the head of it, is expensive. This is due to the need to
  transverse the list until the O(n) position is reached. So, the bigger the
  list, the slowest it will be to access the O(n) position on it.

  Check the implementation for `run_async/2` to understand how the pool list is
  used efficiently by only using the head of it to extract the next pid to run
  the query.

  ## Examples

      iex> pool = DatabaseServer.start_pool 3
      {
        [#PID<0.773.0>, #PID<0.774.0>, #PID<0.775.0>],
        [#PID<0.773.0>, #PID<0.774.0>, #PID<0.775.0>]
      }

  """
  def start_pool(size \\ 10) do
    active_pool = initial_pool = Enum.map(1..size, fn _ -> start() end)
    {active_pool, initial_pool}
  end

  @doc """
  To run each query concurrently a duplicated pool is used, and to understand
  the reason for using this approach you need to read the docs for `start_pool/1`.

  Here we will trigger the reset of the pool to its initial state, aka we will
  rotate the current pool({active_pool, initial_pool}), that is now empty, with
  the initial pool that remains unmodified since it was created in `start_pool/0`.

  ## Examples

  Starting the a pool of `3` servers and sending 4 queries, that will be enough
  to trigger a rotation of the empty `active_pool` with the `initial_pool`:

      iex> pool = DatabaseServer.start_pool(3)
      {[#PID<0.109.0>, #PID<0.110.0>, #PID<0.111.0>], [#PID<0.109.0>, #PID<0.110.0>, #PID<0.111.0>]}

      iex> Enum.scan(["query 1", "query 2", "query 3", "query 4"], pool, fn query, pool -> DatabaseServer.run_concurrently(pool, query) end)
      [
        {[#PID<0.110.0>, #PID<0.111.0>], [#PID<0.109.0>, #PID<0.110.0>, #PID<0.111.0>]},
        {[#PID<0.111.0>],                [#PID<0.109.0>, #PID<0.110.0>, #PID<0.111.0>]},
        {[],                             [#PID<0.109.0>, #PID<0.110.0>, #PID<0.111.0>]},
        {[#PID<0.110.0>, #PID<0.111.0>], [#PID<0.109.0>, #PID<0.110.0>, #PID<0.111.0>]}
      ]
      iex> Enum.map(1..4, fn _ -> DatabaseServer.get_result() end)
      ["query 1 result", "query 2 result", "query 3 result", "query 4 result"]

  Starting with an empty `active_pool`, that will trigger an immediate rotation
  with the `initial_pool`:

      iex> {_active_pool, initial_pool} = DatabaseServer.start_pool(3)
      {[#PID<0.117.0>, #PID<0.118.0>, #PID<0.119.0>], [#PID<0.117.0>, #PID<0.118.0>, #PID<0.119.0>]}

      iex> DatabaseServer.run_concurrently({[], initial_pool}, "query 1")
      {[#PID<0.118.0>, #PID<0.119.0>], [#PID<0.117.0>, #PID<0.118.0>, #PID<0.119.0>]}

      iex> DatabaseServer.get_result()
      "query 1 result"

  Now, try to compare the execution time for all the queries running
  concurrently with them running sequentially, as per example in the
  `run_async/2` docs.

  """
  def run_concurrently({[], initial_pool}, query_def) do
    run_concurrently({initial_pool, initial_pool}, query_def)
  end

  def run_concurrently({[server_pid | active_pool], initial_pool}, query_def) do
    run_async(server_pid, query_def)
    {active_pool, initial_pool}
  end

  @doc """
  When calling this function the server will run it by the order it receives the
  queries, therefore if one takes a long time to return the results, the others
  will have to wait.

  ## Examples

      iex> server_pid = DatabaseServer.start()
      #PID<0.125.0>

      iex> Enum.map(["query 1", "query 2", "query 3"], &DatabaseServer.run_async(server_pid, &1)) |>
           Enum.map(fn _ -> DatabaseServer.get_result() end)
      ["query 1 result", "query 2 result", "query 3 result"]

  To solve this congestion, that increases the overall queries execution time,
  when running the them sequentially, a pool of servers can be created in
  advance and then a different server must pulled from it to run each query. See
  the docs for `run_concurrently/2` to see how to achieve it.

  """
  def run_async(server_pid, query_def) do
    send(server_pid, {:run_query, self(), query_def})
  end

  @doc """
  Gets the results for running the queries from the server process mail box. If
  no results are received in 5 seconds it will exit with a timeout error,
  otherwise it will return all results it received.

  ## Examples

      iex> DatabaseServer.get_result()
      {:error, :timeout}

      iex> server_pid = DatabaseServer.start()
      #PID<0.125.0>

      iex> DatabaseServer.run_async(server_pid, "query 1")
      {:run_query, #PID<0.107.0>, "query 1"}

      iex> DatabaseServer.get_result()
      "query 1 result"

  """
  def get_result() do
    receive do
      {:query_result, result} -> result
    after
      5000 -> {:error, :timeout}
    end
  end

  defp _loop() do
    receive do
      {:run_query, caller, query_def} ->
      send(caller, {:query_result, _run_query(query_def)})
    end

    _loop()
  end

  defp _run_query(query_def) do
    Process.sleep(2000)
    "#{query_def} result"
  end

end
