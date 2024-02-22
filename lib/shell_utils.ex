defmodule Elixecutioner.ShellUtils do
  @moduledoc """
  A collection of shell utilities for `Elixecutioner`.
  """

  def cmd(command, args \\ [], opts \\ []) do
    opts = opts ++ [stderr_to_stdout: true]

    case System.cmd(command, args, opts) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, code} -> {:error, {output, code}}
    end
  end

  def mktemp() do
    cmd("mktemp")
  end

  def rm(path) do
    File.rm(path)
    |> case do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def shell_escape(string) do
    string
    # Escape backslashes first to prevent double escaping
    |> String.replace("\\", "\\\\")
    # Escape double quotes
    |> String.replace("\"", "\\\"")
    # Wrap in double quotes
    |> then(fn escaped -> "\"#{escaped}\"" end)
  end
end
