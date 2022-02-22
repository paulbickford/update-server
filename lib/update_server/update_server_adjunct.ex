defmodule UpdateServerAdjunct do
  use TypeCheck

  alias UpdateServer.Boundary.{Coordinator, Persistence}

  @type! server_name() :: String.t()
  @type! ordinal() :: non_neg_integer()
  @type! server() :: {server_name(), ordinal()}
  @type! servers() :: [server()] | []

  @moduledoc """
  Helper functions to the `UpdateServer` module.

  Functions allow `UpdateServer` to manage
  - Persisting server names
  - Connecting to servers
  - Sending commands to servers

  Note that the current server list includes an associated ordinal number
  to allow easier command line input.
  """

  @doc """
  Connects to server and adds server name to list of persisted servers.

  Returns list of servers and their ordinal numbers.
  """
  @spec! add_server(servers(), server_name()) :: servers() | :error
  def add_server(servers, server_name) do
    case connect_to_server(server_name) do
      {_server_name, ord} ->
        servers = Enum.uniq(List.insert_at(servers, -1, {server_name, ord}))

        get_server_names(servers)
        |> Persistence.write_server_names_to_file()

        UpdateServer.print_server_codes(servers)
        servers

      _ ->
        :error
    end
  end

  @doc """
  Connect to servers.

  Returns server name and ordinal number, or `nil` if connection fails.
  """
  @spec! connect_to_server(server_name()) :: {server_name(), ordinal()} | nil
  def connect_to_server(server_name) do
    case Coordinator.connect(server_name) do
      {:ok, ord} ->
        {server_name, ord}

      {:error, error} ->
        IO.puts("#{server_name} connection failed. Error: \n#{error}")
        nil
    end
  end

  @doc """
  Connects to multiple servers.
  """
  @spec! connect_to_servers([server_name()]) :: servers()
  def connect_to_servers(server_names) do
    for server_name <- server_names do
      connect_to_server(server_name)
    end
    |> Enum.reject(&is_nil(&1))
  end

  @doc """
  Disconnects server and removes it from current server list.
  """
  @spec! disconnect_server(servers(), server_name()) :: :ok
  def disconnect_server(servers, server_name) do
    Coordinator.disconnect(server_name)
    :ok
    # Enum.reject(servers, fn {sn, _ord} -> sn == server_name end)
  end

  @doc """
  Given an integer, returns the cooresponding server name.
  """
  @spec! get_server_name(servers(), ordinal()) :: server_name()
  def get_server_name(servers, ordinal) do
    Enum.find(servers, fn {_server, ord} -> ord == ordinal end)
    |> elem(0)
  end

  @doc """
  Returns a list of server names.
  """
  @spec! get_server_names(servers()) :: [server_name()]
  def get_server_names(servers) do
    for {server_name, _ord} <- servers do
      server_name
    end
  end

  @doc """
  Sends command to multiple servers using server name.
  """
  @spec! send_command_to_servers(servers(), String.t()) :: :ok
  def send_command_to_servers(servers, command) do
    for {server_name, _ord} <- servers do
      Coordinator.send_to_session(server_name, command)
    end

    :ok
  end

  @doc """
  Sends command to multiple servers using server ordinal number.
  """
  @spec! send_command_to_server_codes(servers(), [ordinal()] | [], String.t()) :: :ok
  def send_command_to_server_codes(servers, ordinals, command) do
    case Enum.max(ordinals) < Enum.count(servers) do
      true ->
        Enum.filter(servers, fn {_server_name, ord} -> ord in ordinals end)
        |> send_command_to_servers(command)

      false ->
        IO.puts("#{Enum.max(ordinals)} is not a valid server_number")
    end

    :ok
  end
end
