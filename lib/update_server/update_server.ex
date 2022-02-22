defmodule UpdateServer do
  use Bakeware.Script
  use TypeCheck

  alias UpdateServer.Boundary.{Coordinator, CoordinatorSupervisor, Persistence}
  alias UpdateServer.UI.UISupervisor

  @type! server_name() :: String.t()
  @type! ordinal() :: non_neg_integer()
  @type! server() :: {server_name(), ordinal()}
  @type! servers() :: [server()] | []

  @moduledoc """
  Processes input from the command line and prints messages in the console.

  When started on the command line, the application will first read a list of
  servers from the disk. A connection to each server will be attempted and
  a command, if given, will be sent to each.

  It will then list each connected server with an associated ordinal number
  (essentially a shortcut) to allow easier command line input. These numbers
  are associated to the server at runtime and no not persist between sessions.

  ### Usage
  To start tool:
  > $ update_server cmd

  Each connected server will be listed with an associated ordinal number
  (essentially a shortcut) to allow easier command line input. These numbers
  are associated to the server at runtime and no not persist between sessions.

  Subsequent commands given in the console will be sent to all servers unless
  preceded by `-s <server_number>`, in which case the command will be sent
  only to the given server.

  ### Switches
  <dl>
  <dt>-a [--add] name</dt>
  <dd>Add server to default servers list and connect to server.</dd>
  <dt>-c [--close] server_number</dt>
  <dd>Close connection to server.</dd>
  <dt>-d [--delete] name</dt>
  <dd>Delete server from file. Does not close connection, if connected.</dd>
  <dt>-h [--help]</dt>
  <dd>Help</dd>
  <dt>-l [--list]</dt>
  <dd>List connected servers with codes.</dd>
  <dt>-o [--open] name</dt>
  <dd>Open connection to server, but do not add to default servers list.</dd>
  <dt>-p [--persisted]</dt>
  <dd>List persisted (default) servers.</dd>
  <dt>-q [--quit]</dt>
  <dd>Quit application.</dd>
  <dt>-s [--server] server_number</dt>
  <dd>Server_number to send command to.</dd>
  </dl>
  """

  @doc """
  This is the entry point into the application.

  Receives command line arguments and
  - Starts up the required GenServers
  - Obtains the persisted server list
  - Processes commands given on the command line
  """

  @impl Bakeware.Script
  @spec! main([String.t()]) :: non_neg_integer()
  def main(argv) do
    UISupervisor.start_link()
    CoordinatorSupervisor.start_link()
    Process.monitor(Coordinator)

    Persistence.read_server_names_from_file()
    |> UpdateServerAdjunct.connect_to_servers()
    |> print_server_codes()

    process_input(argv)
  end

  defp display_help do
    IO.puts("""
    To start tool:
    \t$ update_server <cmd>

    Each connected server will be listed with an associated ordinal number
    (essentially a shortcut) to allow easier command line input. These numbers
    are associated to the server at runtime and no not persist between sessions.

    Subsequent commands given in the console will be sent to all servers unless
    preceded by
    \t$ -s <server_number> <cmd>
    in which case the command will be sent
    only to the given server.

    -a [--add] name
    \tAdd server to default servers list and connect to server.
    -c [--close] server_number
    \tClose connection to server.
    -d [--delete] name
    \tDelete server from file. Does not close connection, if connected.
    -h [--help]
    \tHelp
    -l [--list]
    \tList connected servers with codes.
    -o [--open] name
    \tOpen connection to server, but do not add to default servers list.
    -p [--persisted]
    \tList persisted (default) servers.
    -q [--quit]
    \tQuit application.
    -s [--server] server_number
    \tServer_number to send command to.
    """)
  end

  @spec! exit_app() :: :ok
  defp exit_app() do
    System.stop(0)
  end

  @spec! get_formatted_command([String.t()]) :: String.t()
  defp get_formatted_command(command_list) do
    command = Enum.join(command_list, " ")

    if String.ends_with?(command, "\n") do
      command
    else
      command <> "\n"
    end
  end

  @spec! get_ordinals(String.t()) :: [non_neg_integer()]
  def get_ordinals(input) do
    input
    |> String.split(",")
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.to_integer(&1))
  end

  @spec! parse_input([String.t()]) ::
           {keyword(), [String.t()], [{String.t(), String.t() | nil}]}
  defp parse_input(argv) do
    OptionParser.parse_head(argv,
      aliases: [
        a: :add,
        c: :close,
        d: :delete,
        h: :help,
        l: :list,
        o: :open,
        p: :persisted,
        q: :quit,
        s: :server
      ],
      strict: [
        add: :string,
        close: :string,
        delete: :string,
        help: :boolean,
        list: :boolean,
        open: :string,
        persisted: :boolean,
        quit: :boolean,
        server: :string
      ]
    )
  end

  @doc """
  Prints the list of persisted servers.
  """
  @spec! print_persisted_servers() :: :ok
  def print_persisted_servers() do
    Persistence.read_server_names_from_file()
    |> Enum.map(&[&1, "\n"])
    |> IO.puts()

    :ok
  end

  @doc """
  Prints out server names with their corresponding ordinal numbers to the console.
  """
  @spec! print_server_codes(servers()) :: :ok
  def print_server_codes(servers) do
    servers
    |> Enum.map(fn {sn, ord} -> "#{ord} - #{sn}\n" end)
    |> Enum.sort()
    |> IO.puts()

    :ok
  end

  @spec! process_input([String.t()]) :: any()
  defp process_input(argv) do
    {parsed, command_list, invalid} = parse_input(argv)

    if invalid == [] do
      process_input_command(parsed, command_list)
    else
      IO.puts("Invalid switch: #{inspect(invalid)}")
    end

    input =
      IO.gets("$ ")
      |> String.split()

    process_input(input)
  end

  @spec! process_input_command(keyword() | [], [String.t()] | []) :: :ok
  defp process_input_command(switches, command_list) do
    {:ok, servers} = Coordinator.list_servers()

    case Map.new(switches) do
      %{add: server_name} ->
        UpdateServerAdjunct.add_server(servers, server_name)

      %{close: ordinal_string} ->
        ordinal = String.to_integer(ordinal_string)
        server_name = UpdateServerAdjunct.get_server_name(servers, ordinal)

        UpdateServerAdjunct.disconnect_server(servers, server_name)

      %{delete: server_name} ->
        server_names = Persistence.read_server_names_from_file()

        case server_name in server_names do
          true ->
            Persistence.delete_server(server_names, server_name)

          false ->
            IO.puts("Server name not found")
        end

      %{help: true} ->
        display_help()

      %{list: true} ->
        {:ok, servers} = Coordinator.list_servers()

        servers
        |> print_server_codes()

      %{open: server_name} ->
        UpdateServerAdjunct.connect_to_server(server_name)

      %{quit: true} ->
        exit_app()

      %{persisted: true} ->
        print_persisted_servers()

      %{server: server_code_input} ->
        if Enum.any?(command_list) do
          command = get_formatted_command(command_list)
          ordinals = get_ordinals(server_code_input)
          UpdateServerAdjunct.send_command_to_server_codes(servers, ordinals, command)
        end

      %{} ->
        if Enum.any?(command_list) do
          command = get_formatted_command(command_list)
          UpdateServerAdjunct.send_command_to_servers(servers, command)
        end
    end

    :ok
  end
end
