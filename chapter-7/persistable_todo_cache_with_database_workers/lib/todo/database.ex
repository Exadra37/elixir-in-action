defmodule Todo.Database do
  @moduledoc """
  [Chapter 7 - Building a concurrent system > 7.3 Persisting data > 7.3.3 Analyzing the system -> 7.3.4 Addressing the process bottleneck](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/155)
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
    IO.inspect(self(), label: "INIT PID")
    {:ok, nil}
  end

  # @LINK https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/155
  # @LINK https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/163
  #
  # @BOTTLENECK / @CONSISTENCY - The Todo Cache server is running as a singleton
  #   process, therefore the clients are using it synchronously, thus under
  #   heavy load the system may become unresponsive.
  #   A possible solution is to run the Todo.Database server concurrently, and
  #   then clients will use it asynchronously, but this may not be desirable for
  #   the way the data needs to be persisted, like when the order of execution
  #   of operations in the database needs to be respected. To respect this order
  #   the Todo.Database server may use a pool of workers, and always dispatch to
  #   the same worker the same operations that need to run synchronously. For
  #   example, for each todo list name the worker handling it must be always the
  #   same in order to guarantee the consistency of the same, otherwise the todo
  #   list could end-up very quickly in an inconsistent state. This workers will
  #   run in their own processes, thus allowing the Todo.Database to run
  #   concurrently internally, while still being used as a singleton by the
  #   clients and have at the same time the synchronous capabilities to
  #   guarantee order of execution.
  #
  # @POSSIBLE SOLUTION: spawn unlimited one-off worker processes
  #
  #   While the File IO and decoding the binary continues to be expensive
  #   operations, they are now running in another process, thus running
  #   concurrently and not blocking any-more the Todo.Database server from
  #   processing further requests, while it keeps the call synchronous for the
  #   caller, that is waiting for the `GenServer.reply/2` in order to be able to
  #   continue its work.
  #   So, for the caller the Todo.Database continues to be a singleton, but now
  #   the Todo.Database server has an higher throughput and will be able to cope
  #   with more load, while at same time it can create a new File IO bottleneck,
  #   that this time is about having more throughput then the one the Operating
  #   System and hardware the BEAM is running on can handle. This can be solved
  #   with a pool of workers that will continue to provide concurrency, but that
  #   can be constrained on its size to keep File IO from overloading the
  #   underline system.
  #
  # @RACE_CONDITION: The one-off worker processes solution creates a race
  #   condition between reads an writes. The race condition seems to occur
  #   between the file descriptor that `File.write!/2` opens for each write and
  #   the file descriptor for the `File.read/1`. The docs for the `File.write!/2`
  #   says that it truncates the file each time it tries to write to it, thus
  #   running `Todo.Cache.Iex.TryIt.run_cache_server "2020-01-01", "t4"` enough
  #   times it will raise an exception due to reading an empty file, because the
  #   file was open to read in the moment it was truncated to write.

  @impl GenServer
  def handle_cast({:store, key, data}, state) do
    # @LINK https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/point-9338-178-178-0
    #
    # The `cast` operation is now non blocking for the Todo.Database server,
    # because its delegated to an one-off worker process.
    spawn(
      fn ->
        key
        |> _file_name()
        # @LINK https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/155
        #
        # @BOTTLENECK - File IO and encoding to binary are expensive operations. So,
        #               even if takes only microseconds/mileseconds, when the system
        #               is under load, it may become a bottleneck, that will make
        #               the message queue for the process to grow, thus using more
        #               memory. In extreme cases it can bring down the BEAM if the
        #               memory is exhausted. Excessive IO can also make the system
        #               very slow under load. This issues are also proportional to
        #               the size of the todo list.
        |> File.write!(:erlang.term_to_binary(data))
        |> IO.inspect(label: "WRITE RESULT")
      end
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get, key}, caller, state) do
    IO.inspect(state, label: "READ CALL STATE")
    # @LINK https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/155
    #
    # @BOTTLENECK - File IO for reading is less expensive then for writing, but
    #               it can still become a reason to slow down the system during
    #               heavy load. Todo list sizes will also affect throughput.
    #
    # POSSIBLE SOLUTION:
    #
    # @LINK https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/point-9337-181-181-0
    spawn(
      fn ->
        case File.read(_file_name(key)) do
          {:ok, contents} when byte_size(contents) > 0 ->
            IO.inspect(byte_size(contents), label: "READ CONTENTS SIZE")
            # @LINK https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-7/155
            #
            # @BOTTLENECK - Decoding is also an expensive operation that can become
            #               an issue under heavy load.
            #
            # The bottleneck is now diluted because the decoding is happening in
            # another process, therefore not blocking the Todo.Database server
            # from processing more requests. The caller still continues to wait
            # for the decoding to finish, but at this point is not possible to
            # optimize further, and the toll needs to be accepted by the caller.
            GenServer.reply(caller, :erlang.binary_to_term(contents))

          error ->
            IO.inspect(error, label: "READ ERROR")
            GenServer.reply(caller, nil)
        end
      end
    )

    {:noreply, state}
  end

  defp _file_name(key) do
    Path.join(@db_folder, to_string(key))
  end
end
