defmodule Elixecutioner.StateTest do
  use ExUnit.Case

  alias Elixecutioner.State

  setup do
    state =
      case State.new("cat") do
        {:ok, state} -> state
        {:error, _message} -> raise "Failed to initialize state with cat"
      end

    on_exit(fn -> State.terminate(state) end)
    {:ok, state: state}
  end

  describe "new/1" do
    test "creates a new state with a valid command", %{state: state} do
      assert state.port != nil
      assert state.inbox == :queue.new()
      assert not state.closed?
    end
  end

  describe "closed?/1 and terminated?/1" do
    test "initially, state is not closed nor terminated", %{state: state} do
      assert not State.closed?(state)
      assert not State.terminated?(state)
    end
  end

  describe "close/1" do
    test "marks the state as closed", %{state: state} do
      state = State.close(state)
      assert State.closed?(state)
    end
  end

  describe "terminate/1" do
    test "terminates the state correctly", %{state: state} do
      state = State.terminate(state)
      assert State.terminated?(state)
    end
  end

  describe "write/2" do
    test "raises a ClosedError when terminated", %{state: state} do
      state = State.terminate(state)
      assert State.terminated?(state)

      assert_raise(Elixecutioner.State.ClosedError, "the process has exited", fn ->
        State.write(state, "fnord")
      end)
    end

    test "raises a ClosedError when closed", %{state: state} do
      state = State.close(state)
      assert State.closed?(state)

      assert_raise(Elixecutioner.State.ClosedError, "the process is closed further input", fn ->
        State.write(state, "fnord")
      end)
    end
  end

  describe "read/2" do
    test "delivers a message", %{state: state} do
      State.write(state, "fnord")
      assert {{:stdout, "fnord"}, ^state} = State.read(state, 5000)
    end

    test "multiple messages are delivered in the expected order", %{state: state} do
      State.write(state, "fnord1")
      State.write(state, "fnord2")
      State.write(state, "fnord3")

      assert {{:stdout, "fnord1"}, state} = State.read(state, 5000)
      assert {{:stdout, "fnord2"}, state} = State.read(state, 5000)
      assert {{:stdout, "fnord3"}, state} = State.read(state, 5000)

      assert {:empty, _} = State.read(state, 0)
    end

    test "returns :empty when the inbox is empty", %{state: state} do
      assert {:empty, _} = State.read(state, 0)
    end

    test "returns :closed when closed and the inbox is empty", %{state: state} do
      state = State.terminate(state)
      assert {:exited, _} = State.read(state, 0)
    end

    test "returns :exited when terminated and the inbox is empty", %{state: state} do
      state = State.terminate(state)
      assert {:exited, _} = State.read(state, 0)
    end

    test "returns queued message despite being closed", %{state: state} do
      State.write(state, "fnord")
      Process.sleep(100)
      state = State.close(state)
      assert {{:stdout, "fnord"}, _} = State.read(state, 5000)
    end

    test "returns queued message despite being terminated", %{state: state} do
      State.write(state, "fnord")
      Process.sleep(100)
      state = State.terminate(state)
      assert {{:stdout, "fnord"}, _} = State.read(state, 5000)
    end
  end
end
