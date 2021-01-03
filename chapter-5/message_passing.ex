defmodule MessagePassing do

  @moduledoc """
  ## 5.2.2 Message passing

  Following along [Message passing](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-5/60).

  Sending messages takes the form of:

  ```elixir
  send(pid, {:an, :arbitrary, :term})
  ```

  Receiving the message can be done with:

  ```elixir
  receive do
    pattern_1 ->
      do_something
    pattern_2 ->
      do_something_else
  end
  ```

  When a received message doesn't match any of the patterns in the receive block
  it's put back in the process mailbox of the receiver.

  The alternative is to catch any message:

  ```elixir
  receive do
    pattern_1 ->
      do_something
    pattern_2 ->
      do_something_else
    _ ->
      catch_all_messages_not_matched_before
  end
  ```

  The above receive blocks examples will run until they receive a message and
  then they will exit, thus they can wait forever for the message to arrive, and
  meanwhile they may be blocking further code from being executed, unless it's
  running on a separated process.

  To only wait for messages for a certain period of time, do instead:

  ```elixir
  receive do
    pattern_1 ->
      do_something
    pattern_2 ->
      do_something_else
     _ ->
      catch_all_messages_not_matched_before
  after
    5000 ->
      IO.puts("Not listening for more new messages after waiting for 5 seconds.")
  end
  ```

  So, any message sent to the process after the 5 seconds will be kept in the
  process mailbox until they are explicitly flushed or retrieved by running
  again the receive block.

  A better approach exists, that consists in using tail recursion in a dedicated
  function for the receive block that will run in an infinite loop on a
  separated server Process, as we will see in the next section: 5.3.1 - Server Processes.

  """

  def run_query(query_def) do
    Process.sleep(2000)
    "#{query_def} result"
  end

  @doc """

  ## Examples

    iex> 1..5 |> Enum.map(&MessagePassing.send("select * from table-&1")) |> Enum.map(fn _ -> MessagePassing.get_result() end)
  """
  def send(query_def) do
    caller_pid = self()

    spawn(
      fn ->
        # The `send/2` function will run in the spawned process and send back to
        # the caller a message with the result, that the caller will retrieve
        # with `get_result/0`.
        send(caller_pid, {:query_result, run_query(query_def)})
      end
    )
  end

  def get_result() do
    receive do
      {:query_result, result} ->
        result
    end
  end

end
