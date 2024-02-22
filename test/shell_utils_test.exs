defmodule Elixecutioner.ShellUtilsTest do
  use ExUnit.Case, async: true

  alias Elixecutioner.ShellUtils

  describe "cmd/3" do
    test "runs a command" do
      assert {:ok, "hello"} = ShellUtils.cmd("echo", ["hello"])
    end
  end

  describe "mktemp/0" do
    test "creates a temporary file" do
      {:ok, path} = ShellUtils.mktemp()
      assert File.exists?(path)
      assert File.regular?(path)
      assert "" = File.read!(path)
      assert :ok = ShellUtils.rm(path)
    end
  end

  describe "shell_escape/1" do
    test "escapes backslashes" do
      # lol win32
      assert ShellUtils.shell_escape("C:\\Windows\\System32") == "\"C:\\\\Windows\\\\System32\""
    end

    test "escapes double quotes" do
      assert ShellUtils.shell_escape("He said, \"Hello\"") == "\"He said, \\\"Hello\\\"\""
    end

    test "handles empty strings" do
      assert ShellUtils.shell_escape("") == "\"\""
    end

    test "handles strings without special characters" do
      input = "simple_string123"
      expected = "\"#{input}\""
      assert ShellUtils.shell_escape(input) == expected
    end

    test "properly escapes a combination of backslashes and double quotes" do
      input = "\\\"Hello, World!\\\""
      expected = "\"\\\\\\\"Hello, World!\\\\\\\"\""
      assert ShellUtils.shell_escape(input) == expected
    end

    test "handles strings with only backslashes" do
      assert ShellUtils.shell_escape("\\\\") == "\"\\\\\\\\\""
    end

    test "handles strings with only double quotes" do
      assert ShellUtils.shell_escape("\"\"\"") == "\"\\\"\\\"\\\"\""
    end
  end
end
