defmodule ElixecutionerTest do
  use ExUnit.Case
  use Elixecutioner

  doctest Elixecutioner

  test "happy path" do
    {:ok, proc} = cmd("cat")
    refute Elixecutioner.closed?(proc)
    refute Elixecutioner.terminated?(proc)

    Elixecutioner.write(proc, "fnord")
    Elixecutioner.write(proc, "slack")

    assert {:stdout, "fnord"} = Elixecutioner.read(proc)
    assert {:stdout, "slack"} = Elixecutioner.read(proc)

    refute Elixecutioner.closed?(proc)
    refute Elixecutioner.terminated?(proc)

    Elixecutioner.close(proc)
    assert Elixecutioner.closed?(proc)
    refute Elixecutioner.terminated?(proc)
    assert :closed = Elixecutioner.read(proc)

    Elixecutioner.terminate(proc)
    assert Elixecutioner.closed?(proc)
    assert Elixecutioner.terminated?(proc)
    assert :exited = Elixecutioner.read(proc)
  end
end
