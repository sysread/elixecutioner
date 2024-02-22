defmodule Elixecutioner do
  @moduledoc """
  Elixecutioner is a simple Elixir library for running shell commands, allowing
  commands to be executed asynchronously while treating their output as a
  stream.
  """

  use GenServer

  alias Elixecutioner.State

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  defmacro __using__(_opts) do
    quote do
      import Elixecutioner,
        only: [
          e: 1,
          cmd: 1,
          cmd: 2
        ]
    end
  end

  @doc """
  Escape a string for use in a shell command.
  """
  defmacro e(string) do
    quote do
      Elixecutioner.ShellUtils.shell_escape(unquote(string))
    end
  end

  @doc """
  Run a shell command.
  """
  defmacro cmd(command) do
    quote do
      Elixecutioner.start_link(unquote(command))
    end
  end

  @doc """
  Run a shell command with arguments. The command itself is used untouched; the
  arguments are escaped for the shell.
  """
  defmacro cmd(command, args) do
    quote do
      (unquote(command) <>
         " " <>
         (unquote(args)
          |> Enum.map(&Elixecutioner.e/1)
          |> Enum.join(" ")))
      |> Elixecutioner.cmd()
    end
  end

  # ----------------------------------------------------------------------------
  # Client
  # ----------------------------------------------------------------------------
  @doc """
  Start a new Elixecutioner process.
  """
  def start_link(command) do
    GenServer.start_link(__MODULE__, command)
  end

  @doc """
  Returns `true` if the process has terminated.
  """
  def terminated?(pid) do
    GenServer.call(pid, :terminated?)
  end

  @doc """
  Terminate the process.
  """
  def terminate(pid) do
    GenServer.cast(pid, :terminate)
  end

  @doc """
  Returns `true` if the command has been closed to new input.
  """
  def closed?(pid) do
    GenServer.call(pid, :closed?)
  end

  def close(pid) do
    GenServer.cast(pid, :close)
  end

  def write(pid, msg) do
    GenServer.cast(pid, {:write, msg})
  end

  def recv(pid) do
    GenServer.call(pid, {:read, 0}, 100)
  end

  def read(pid, timeout \\ :infinity) do
    GenServer.call(pid, {:read, timeout}, timeout)
  end

  # ----------------------------------------------------------------------------
  # Server
  # ----------------------------------------------------------------------------
  @impl true
  def init(command) do
    case State.new(command) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_cast(:close, state) do
    {:noreply, State.close(state)}
  end

  @impl true
  def handle_cast(:terminate, state) do
    {:noreply, State.terminate(state)}
  end

  @impl true
  def handle_cast({:write, msg}, state) do
    {:noreply, State.write(state, msg)}
  end

  @impl true
  def handle_call(:closed?, _from, state) do
    {:reply, State.closed?(state), state}
  end

  @impl true
  def handle_call(:terminated?, _from, state) do
    {:reply, State.terminated?(state), state}
  end

  @impl true
  def handle_call({:read, timeout}, _from, state) do
    {msg, state} = State.read(state, timeout)
    {:reply, msg, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, state) do
    {:noreply, State.set_terminated(state)}
  end

  def handle_info({_pid, :closed}, state) do
    {:noreply, State.set_terminated(state)}
  end

  def handle_info(msg, state) do
    raise """
    UNHANDLED MESSAGE

    This likely indicates a missing GenServer callback implementation.

    ----------
    Message
    ----------
    #{inspect(msg)}

    ----------
    State
    ----------
    #{inspect(state)}

    """
  end
end
