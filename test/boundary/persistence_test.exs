defmodule PersistenceTest do
  use ExUnit.Case, async: false

  alias UpdateServer.Boundary.Persistence

  setup do
    path = "test/.config_test"
    Persistence.write_server_names_to_file([], path)

    on_exit(fn -> Persistence.write_server_names_to_file([], path) end)

    %{path: path}
  end

  test "adds one server to persisted list", %{path: path} do
    servers = Persistence.read_server_names_from_file(path)
    refute "server1" in servers

    Persistence.write_server_names_to_file(["server1"], path)
    servers = Persistence.read_server_names_from_file(path)

    assert "server1" in servers
  end

  test "adds multiple servers to persisted list", %{path: path} do
    servers = Persistence.read_server_names_from_file(path)

    refute "server1" in servers
    refute "server2" in servers

    Persistence.write_server_names_to_file(["server1", "server2"], path)
    servers = Persistence.read_server_names_from_file(path)

    assert "server1" in servers
    assert "server2" in servers
  end

  test "deletes one server from persisted list", %{path: path} do
    Persistence.write_server_names_to_file(["server1", "server2"], path)
    servers = Persistence.read_server_names_from_file(path)

    assert "server1" in servers
    assert "server2" in servers

    Persistence.delete_server(servers, "server1", path)
    servers = Persistence.read_server_names_from_file(path)

    assert "server2" in servers
    refute "server1" in servers
  end
end
