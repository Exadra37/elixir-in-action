defmodule Processes do
  @moduledoc """
  ## 5.2 Working with Processes

  Following along [chapter 5.2](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-5/29).

  In the BEAM everything is a process and they run concurrently, and in
  multi-core processors they can also run in parallel.

  Even when don't explicitly spawn a process to run our code the BEAM is running
  it in one. Processes in the BEAM run in total isolation from each other,
  therefore any code can run 100% safely concurrently and in parallel, thus
  without the need to use any control mechanisms, like semaphores, lockers, etc.

  When the BEAM runs a set of processes concurrently in a processor with only 1
  core it may increase or not the speed for running this set of processes, but
  it will ensure for sure that none of them starve the server resources, thus
  affecting the other processes wanting to run or already running. On the other
  hand, running the a set of processes in a multi-core processor will run them
  concurrently and in parallel, thus the overall processing time for the entire
  set will be for sure a lot less, but will not be necessarily proportional to
  the number of cores available.

  When executing processes concurrently the BEAM doesn't guarantee the order of
  execution.

  [Quote](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-5/point-9293-33-34-0):

      CONCURRENCY VS. PARALLELISM
      It’s important to realize that concurrency doesn’t necessarily imply
      parallelism. Two concurrent things have independent execution contexts, but
      this doesn’t mean they will run in parallel. If you run two CPU-bound
      concurrent tasks and you only have one CPU core, parallel execution can’t
      happen. You can achieve parallelism by adding more CPU cores and relying on
      an efficient concurrent framework. But you should be aware that concurrency
      itself doesn’t necessarily speed things up.

  """

  @doc """
  Running the prime numbers calculation synchronously means that we will be
  blocked while waiting for its execution to finish.

  ## Examples:

      iex> sync = Processes.sync_function()
      #Function<1.85766218/1 in Processes.sync_function/0>

  The execution of the query will block the shell until the result is printed to
  the screen:

      iex> sync.(1..20000)
      {:ok,
       %{
         prime_numbers: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53,
          59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137,
          139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, ...],
         seconds: 3.006718
       }}

  Now, let's say we need to compute the prime number for 3 ranges:

      iex> :timer.tc fn -> Enum.each([1..20000, 1..20000, 1..20000], IO.inspect(&sync.(&1))) end
      #Function<44.97283095/1 in :erl_eval.expr/5>
      {8716658, :ok}

  The Shell was blocked during 8.7 seconds, that's almost the triple of the
  time it took to process the same range only one time, and that's doesn't come
  as a surprise, because they were calculated one after the other. So, this can
  be improved if we can run the code concurrently and in parallel.

  """
  def sync_function() do
    fn range ->
      PrimeNumbers.find(range)
    end
  end

  @doc """
  ## Run Code Asynchronously

  Running the prime numbers calculation asynchronously means the code will be
  executed concurrently in another process on the background, thus not blocking
  the current process while is being executed.

  ### Example

      iex> async = Processes.async_function()
      #Function<0.112339615/1 in Processes.async_function/0>

  The execution of the code will run in another process, identified by the PID,
  thus we get the shell back immediately:

      iex> async.(1..20000)
      #PID<0.197.0>

  Using the shell while waiting for the `asycn` function to return the result:

      iex> IO.puts "Waiting..."
      Waiting...
      :ok
      {:ok,
       %{
         prime_numbers: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53,
          59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137,
          139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, ...],
         seconds: 2.9790419
       }}

  So, the execution time is very similar to the running it synchronously, but
  the main difference is that we don't need to wait for it to be executed to
  continue to use shell or allow the program to run other code.

  ## Run Code Concurrently

  When we use the `spawn/0` to start another process and pass to it some data,
  like done with the `range` variable, a deep copy of it will be performed
  by the BEAM to each of the spawned processes, because in the BEAM processes
  share nothing with each other.

  ### Example

      iex> async = Processes.async_function
      #Function<0.85766218/1 in Processes.async_function/0>

  Now lets run the asynchronous function concurrently where each one will run in
  its own process, that share nothing with each other, memory or whatever:

      iex> Enum.each([1..20000, 1..20000, 1..20000], &async.(&1))
      :ok

  So, we can still use the shell while all the processes running concurrently:

      iex> IO.puts("Waiting...")
      Waiting...
      :ok
      {:ok,
       %{
         prime_numbers: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53,
          59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137,
          139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, ...],
         seconds: 3.12077
       }}
      {:ok,
       %{
         prime_numbers: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53,
          59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137,
          139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, ...],
         seconds: 3.564592
       }}
      {:ok,
       %{
         prime_numbers: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53,
          59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137,
          139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, ...],
         seconds: 3.567582
       }}

  And now we get all the results back in around 3.7 seconds, that's just a
  little more then the time it takes to process the slowest of the prime numbers
  calculation. This is a lot better then the previous 8.7 ish seconds when
  we were not running them concurrently and in parallel.

  Try again to run the code concurrently, but this time start iex configured
  to use only 1 processor core and one BEAM scheduler `iex --erl "+S 1:1"`, and
  you will see that the times it takes to process it all is around the same as
  when doing it synchronously, being the only difference that we are not blocked
  while waiting for the processing to be completed.

  """
  def async_function() do
    fn range ->
      # The `range` var is deep copied to the spawned process.
      spawn(fn -> sync_function().(range) |> IO.inspect() end)
    end
  end

end


# @link https://www.kabisa.nl/tech/when-elixirs-performance-becomes-rust-y/
defmodule PrimeNumbers do
  # http://erlang.org/doc/efficiency_guide/listHandling.html

  def find(numbers) when is_list(numbers) do
    _prime_numbers(numbers, [])
  end

  def find(range) do
    start_time = :os.system_time(:microsecond)

    prime_numbers =
      range
      |> Enum.to_list()
      |> _prime_numbers([])

    {
      :ok,
      %{
        seconds: (:os.system_time(:microsecond) - start_time) / 1000000,
        prime_numbers: prime_numbers
      }
    }
  end

  defp _prime_numbers([], result) do
    result |> Enum.reverse()
  end

  defp _prime_numbers([number | rest], result) do
    new_result = result
    |> _add_if_prime_number(number)

    _prime_numbers(rest, new_result)
  end

  defp _add_if_prime_number(numbers, 1), do: numbers

  defp _add_if_prime_number(numbers, 2) do
    [2 | numbers]
  end

  defp _add_if_prime_number(numbers, n) do
    range = 2..(n - 1)
    case Enum.any?(range, fn x -> rem(n, x) == 0 end) do
      false -> [n | numbers]
      _ -> numbers
    end
  end
end
