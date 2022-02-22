defmodule ConnectionTest do
  use ExUnit.Case, async: true

  alias UpdateServer.Boundary.Connection

  test "are temporary workers" do
    assert Supervisor.child_spec(Connection, []).restart == :temporary
  end
end
