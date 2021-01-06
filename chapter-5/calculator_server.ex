defmodule Calculator do
  @moduledoc """
  [Chapter 5 - Concurrency primitives > 5.3 Stateful server processes > 5.3.3 Mutable state](https://livebook.manning.com/book/elixir-in-action-second-edition/chapter-5/point-9314-175-175-0).

  This an example how processes can be used to keep state that can be mutated.

  ## Examples
      iex> pid = Calculator.start
      #PID<0.215.0>

      iex> Calculator.value pid
      0

      iex> Calculator.add pid, 10
      {:add, 10}

      iex> Calculator.sub pid, 5
      {:sub, 5}

      iex> Calculator.mul pid, 3
      {:mul, 3}

      iex> Calculator.div pid, 5
      {:div, 5}

      iex> Calculator.value pid
      3.0

  """

  ###########
  # CLIENT
  ###########

  @doc """
  Starts the Calculator server.

  ## Examples

      iex> pid = Calculator.start
      #PID<0.215.0>
  """
  def start() do
    spawn(fn -> _loop(0) end)
  end

  @doc """
  Retrieves the current Calculator sever state.

      iex> pid = Calculator.start
      #PID<0.215.0>

      iex> Calculator.value pid
      0

  """
  def value(server_pid) do
    send(server_pid, {:value, self()})

    receive do
      {:response, value} ->
        value
    end
  end

  # All supported operations for the Calculator server
  def add(server_pid, value), do: send(server_pid, {:add, value})
  def sub(server_pid, value), do: send(server_pid, {:sub, value})
  def mul(server_pid, value), do: send(server_pid, {:mul, value})
  def div(server_pid, value), do: send(server_pid, {:div, value})


  ###########
  # SERVER
  ###########

  # Tail recursive function that keeps the server state, by calling itself with
  # the new value or the same unchanged value.
  defp _loop(current_value) do
    new_value =
      receive do
        message ->
          _proccess_message(current_value, message)
      end

    _loop(new_value)
  end

  # Retrieves the current server state
  defp _proccess_message(current_value, {:value, caller}) do
    send(caller, {:response, current_value})
    current_value
  end

  # Mutates the server state
  defp _proccess_message(current_value, {:add, value}) do
    current_value + value
  end

  # Mutates the server state
  defp _proccess_message(current_value, {:sub, value}) do
    current_value - value
  end

  # Mutates the server state
  defp _proccess_message(current_value, {:mul, value}) do
    current_value * value
  end

  # Mutates the server state
  defp _proccess_message(current_value, {:div, value}) do
    current_value / value
  end

  # Handles requests not supported by the server
  defp _proccess_message(current_value, invalid_request) do
    IO.puts("invalid request #{inspect invalid_request}")
    current_value
  end

end
