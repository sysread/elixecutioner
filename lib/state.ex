defmodule Elixecutioner.State do
  @moduledoc """
  The state module for the Elixecutioner. This module is responsible for
  managing the state of the Elixecutioner process. This module is used
  internally by `Elixecutioner` and should not be used directly.
  """

  defstruct [
    :port,
    :inbox,
    :closed?
  ]

  @type t :: %__MODULE__{
          port: proc,
          inbox: inbox,
          closed?: boolean
        }

  @type msg ::
          {:stdout, String.t()}
          | {:stderr, String.t()}
          | :empty
          | :closed

  @typep inbox :: :queue.queue(msg)
  @typep proc :: port | nil

  defmodule ClosedError do
    defexception [:message]
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------
  @spec new(String.t()) :: {:ok, t} | {:error, String.t()}
  def new(cmd) do
    try do
      port = Port.open({:spawn, cmd}, [:line, :binary])

      {:ok,
       %__MODULE__{
         port: port,
         inbox: :queue.new(),
         closed?: false
       }}
    rescue
      ex ->
        formatted = Exception.format(:error, ex, __STACKTRACE__)
        {:error, formatted}
    end
  end

  @spec closed?(t) :: boolean
  def closed?(%{closed?: closed?}), do: closed?

  @spec close(t) :: t
  def close(%{closed?: true} = state), do: state

  def close(state) do
    %__MODULE__{drain_port(state, 0) | closed?: true}
  end

  @spec terminated?(t) :: boolean
  def terminated?(%{port: nil}), do: true
  def terminated?(_), do: false

  @spec terminate(t) :: t
  def terminate(%{port: nil} = state), do: state

  def terminate(state) do
    send(state.port, {self(), :close})
    set_terminated(state)
  end

  @spec set_terminated(t) :: t
  def set_terminated(%{port: nil} = state), do: state

  def set_terminated(state) do
    state = close(state)
    %__MODULE__{drain_port(state, 0) | closed?: true, port: nil}
  end

  @spec write(t, String.t()) :: t
  def write(%{port: nil}, _) do
    raise ClosedError, "the process has exited"
  end

  def write(%{closed?: true}, _) do
    raise ClosedError, "the process is closed further input"
  end

  def write(state, msg) do
    Port.command(state.port, "#{msg}\n")
    state
  end

  @spec read(t, non_neg_integer) :: {msg, t}
  def read(%{port: nil} = state, _) do
    drain_port(state, 0) |> take_msg()
  end

  def read(state, timeout) do
    timeout = drain_port_timeout(state, timeout)
    drain_port(state, timeout) |> take_msg()
  end

  # ----------------------------------------------------------------------------
  # Internals
  # ----------------------------------------------------------------------------
  defp drain_port_timeout(%{closed?: true}, _timeout), do: 0
  defp drain_port_timeout(%{inbox: {[], []}}, timeout), do: timeout
  defp drain_port_timeout(%{inbox: {_, [_]}}, _timeout), do: 0

  defp drain_port(%{port: port} = state, timeout) do
    receive do
      {^port, {:data, {:eol, line}}} -> state |> put_msg({:stdout, line}) |> drain_port(0)
      {^port, {:error, {:eol, line}}} -> state |> put_msg({:stderr, line}) |> drain_port(0)
      {^port, :closed} -> state |> set_terminated()
    after
      timeout -> state
    end
  end

  defp put_msg(state, msg) do
    Map.update!(state, :inbox, &:queue.in(msg, &1))
  end

  defp take_msg(state) do
    case :queue.out(state.inbox) do
      {{:value, msg}, inbox} ->
        {msg, %{state | inbox: inbox}}

      {:empty, _} ->
        case state do
          %{port: nil} -> {:exited, state}
          %{closed?: true} -> {:closed, state}
          _ -> {:empty, state}
        end
    end
  end
end
