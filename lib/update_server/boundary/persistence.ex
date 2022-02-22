defmodule UpdateServer.Boundary.Persistence do
  use TypeCheck

  @type! server_name() :: String.t()

  @moduledoc """
  Reads and writes server list to disk.

  Allows commonly used servers to automatically be connected to
  without having to add them each time.
  """
  @config_path "~/.update_server.conf"

  @doc """
  Deletes the server from the persisted list.

  Returns new list of persisted server names.

  Does not affect any existing connections.
  """
  @spec! delete_server([server_name() | []], server_name(), String.t()) :: [server_name()] | []
  def delete_server(server_names, server_name, path \\ @config_path) do
    server_names = Enum.filter(server_names, fn sn -> sn != server_name end)
    write_server_names_to_file(server_names, path)
    server_names
  end

  @doc """
  Returns a list of persisted server names.
  """
  @spec! read_server_names_from_file(String.t()) :: [server_name()] | []
  def read_server_names_from_file(path \\ @config_path) do
    case File.read(Path.expand(path)) do
      {:ok, encoded_file} ->
        encoded_file
        |> JSON.decode!()
        |> Map.get("servers", [])

      {:error, _reason} ->
        write_server_names_to_file([])
        []
    end
  end

  @doc """
  Writes server name to presisted server list.

  Returns `:ok ` or raises.
  """
  @spec! write_server_names_to_file([server_name()] | [], String.t()) :: :ok
  def write_server_names_to_file(server_names, path \\ @config_path) do
    encoded_server_names = JSON.encode!(servers: server_names)
    File.write!(Path.expand(path), encoded_server_names)
  end
end
