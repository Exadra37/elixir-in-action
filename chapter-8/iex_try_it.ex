defmodule IexTryIt do
  @moduledoc """
  [Chapter 8 - Fault-tolerance basics > 8.1 Runtime errors -> 8.2 Errors in concurrent systems](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-8/)

  """

  @doc """
  Try catch examples.

  ## Examples

      iex> try_catch = IexTryIt.try_catch
      #Function<0.78563054/1 in IexTryIt.try_catch/0>

      iex> try_catch.(fn -> raise("Something went wrong") end)
      Error
        :error
        %RuntimeError{message: "Something went wrong"}
      :ok
      iex> try_catch.(fn -> throw "Something went wrong" end)
      Error
        :throw
        "Something went wrong"
      :ok
      iex> try_catch.(fn -> exit "Something went wrong" end)
      Error
        :exit
        "Something went wrong"
      :ok

  """
  def try_catch() do
    fn fun ->
      try do
        fun.()
        IO.puts("No error.")
      catch type, value ->
        IO.puts("Error\n  #{inspect(type)}\n  #{inspect(value)}")
      end
    end
  end

  @doc """

  ## Examples

  iex> IexTryIt.try_catch_all
  Error caught
  Cleanup code, e.g: close an open file
  :ok

  """
  def try_catch_all() do
    try do
      raise("Something went wrong")
    catch
      _,_ ->
        IO.puts("Error caught")
    after
      IO.puts("Cleanup code, e.g: close an open file")
    end
  end

  @doc """
  Example to show that when the parent process crashes, the children process it
  has spawned doesn't crash, because the processes are running in isolation and
  are not linked.

  ## Example

      iex> IexTryIt.parent_process_crash
      #PID<0.168.0>

      iex>
      09:44:21.266 [error] Process #PID<0.168.0> raised an exception
      ** (RuntimeError) Something went wrong
          iex_try_it.ex:71: anonymous fn/0 in IexTryIt.parent_process_crash/0

      iex> IO.puts "---> Waiting for Process 2 too finish..."
      ---> Waiting for Process 2 too finish...
      :ok
      Process 2 finished

  """
  def parent_process_crash() do
    spawn(
      fn ->
        spawn(
          fn ->
            Process.sleep(1000)
            IO.puts("Process 2 finished")
          end
        )

        raise("Something went wrong in the Parent process 1.")
      end
    )
  end

  @doc """
  To exemplify how a crash in a linked processes causes the immediate
  termination of the other linked process.

  This is bidirectional, therefore if the raise was in the children process the
  process being terminated would have been the parent process.

  The process that crashes emits an exit signal to the all the other ones is
  linked too, and if they don't handle the exit signal they will be also
  terminated by the BEAM.

  ## Examples

      iex> IexTryIt.parent_linked_process_crash
      #PID<0.206.0>

      10:04:03.130 [error] Process #PID<0.206.0> raised an exception
      ** (RuntimeError) Something went wrong in Process 1. Once the two processes are linked, the inner spawned Process 2 will terminate immediately.
          iex_try_it.ex:105: anonymous fn/0 in IexTryIt.parent_linked_process_crash/0

  Here we can see that the children Process 2 was terminated by the BEAM because
  it has not handled the exit signal from the parent process that is linked to,
  aka the one that have spawned it.
  """
  def parent_linked_process_crash() do
    spawn(
      fn ->
        spawn_link(
          fn ->
            Process.sleep(1000)
            IO.puts("Process 2 finished")
          end
        )

        raise("Something went wrong in the parent Process 1. Once the two processes are linked, the children Process 2 will be also terminated by the Beam.")
      end
    )
  end

  @doc """
  Trap the exit of a linked children process.

  ## Example

      iex> IexTryIt.trap_children_linked_process_crash
      Process 2 will be spawned...
      #PID<0.292.0>
      Waiting for exit signal from children Process 2...

      iex>
      23:16:22.571 [error] Process #PID<0.293.0> raised an exception
      ** (RuntimeError) Something went wrong in the children Process 2.
          iex_try_it.ex:164: anonymous fn/0 in IexTryIt.trap_children_linked_process_crash/0
      {:EXIT, #PID<0.293.0>,
       {%RuntimeError{message: "Something went wrong in the children Process 2."},
        [
          {IexTryIt, :"-trap_children_linked_process_crash/0-fun-0-", 0,
           [file: 'iex_try_it.ex', line: 164]}
        ]}}

  """
  def trap_children_linked_process_crash() do
    spawn(
      fn ->
        Process.flag(:trap_exit, true)

        IO.puts("Process 2 will be spawned...")

        spawn_link(
          fn ->
            raise("Something went wrong in the children Process 2.")
          end
        )

        IO.puts("Waiting for exit signal from children Process 2...")

        receive do
          {:EXIT, _pid, _reason} = exit_signal ->
            IO.inspect(exit_signal)
        end
      end
    )
  end

  @doc """
  Instead of linking processes we can just monitor the children process we
  spawn and get notified when they die, but if the parent processes die it will
  not cause the children to die due to the bidirectional nature of linked
  processes.

  The processor monitor is uni-directional, aka, only the process that created
  the monitor will receive messages from the children processes it spawns, and
  can choose to ignore or handle it, but it will never crash because the process
  is monitoring has crashed, like in the linked processes.

  that same processes will not be notified or crash when the parent process that
  created them dies.

  Also, the process doing the monitor, will not
  ## Example

      iex> IexTryIt.monitor_process
      "{:DOWN, #Reference<0.1646239263.2154561537.218342>, :process, #PID<0.330.0>, :normal}"

  """
  def monitor_process() do
    children_pid = spawn(
      fn ->
        IO.puts("Process being monitored doing it's work...")
        Process.sleep(1000)
      end
    )

    Process.monitor(children_pid)

    receive do
      {:DOWN, _monitor_reference, :process, _pid_or_node, _reason} = monitor_signal ->
        inspect(monitor_signal)
    end
  end

  @doc """
  When a process being monitored crashes the monitor process will receive a
  signal with the reason, and can decide to do nothing or may want to restart
  the process again.

  ## Example

      iex> IexTryIt.process_being_monitored_crashes
      Process being monitored doing it's work...
      #PID<0.453.0>

      22:35:24.839 [error] Process #PID<0.454.0> raised an exception
      ** (RuntimeError) Something went wrong!!!
          iex_try_it.ex:227: anonymous fn/0 in IexTryIt.process_being_monitored_crashes/0
      {:DOWN, #Reference<0.1646239263.2154561537.218834>, :process, #PID<0.454.0>,
       {%RuntimeError{message: "Something went wrong!!!"},
        [
          {IexTryIt, :"-process_being_monitored_crashes/0-fun-0-", 0,
           [file: 'iex_try_it.ex', line: 227]}
        ]}}
      Process.alive?: false
      :ok
  """
  def process_being_monitored_crashes() do
    spawn(
      fn ->
        children_pid = spawn(
          fn ->
            IO.puts("Process being monitored doing it's work...")
            Process.sleep(500)
            raise("Something went wrong!!!")
          end
        )

        Process.monitor(children_pid)

        receive do
          {:DOWN, _monitor_reference, :process, _pid_or_node, _reason} = monitor_signal ->
            IO.inspect(monitor_signal)

            Process.alive?(children_pid)
            |> IO.inspect(label: "Process.alive?")
        end
      end
    )

    # Before we exit, lets' wait for the children process being monitor to crash.
    Process.sleep(1000)
  end

  @doc """
  When a process monitoring other process dies it will not send a exit signal,
  therefore the process being monitored will not be killed by the BEAM as it
  occurs in linked processes.

  ## Examples

      iex> IexTryIt.monitor_process_crashes
      Children process being monitored doing it's work...

      22:57:51.743 [error] Process #PID<0.548.0> raised an exception
      ** (RuntimeError) Parent process: Something went wrong!!!
          iex_try_it.ex:284: anonymous fn/1 in IexTryIt.monitor_process_crashes/0
      Children process being monitored still doing it's work...
      Children process -> Process.alive?: true
      Parent process monitor -> Process.alive?: false
      false

  """
  def monitor_process_crashes() do
    pid = self()

    spawn(
      fn ->
        parent_pid = self()

        children_pid = spawn(
          fn ->
            IO.puts("Children process being monitored doing it's work...")
            Process.sleep(500)
            IO.puts("Children process being monitored still doing it's work...")
            Process.sleep(1500)
          end
        )

        Process.monitor(children_pid)

        send(pid, {:parent_pid, parent_pid, :children_pid, children_pid})

        raise("Parent process: Something went wrong!!!")

        receive do
          {:DOWN, _monitor_reference, :process, _pid_or_node, _reason} = monitor_signal ->
            IO.inspect(monitor_signal)
        end
      end
    )

    receive do
      {:parent_pid, parent_pid, :children_pid, children_pid} ->
        # Let's wait for the children process to do some work before the crash
        # in the parent process monitor
        Process.sleep(1000)

        Process.alive?(children_pid)
        |> IO.inspect(label: "Children process -> Process.alive?")

        Process.alive?(parent_pid)
        |> IO.inspect(label: "Parent process monitor -> Process.alive?")
    end
  end
end
