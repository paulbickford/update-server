defmodule UpdateServer.Boundary.Coordinator do
  use GenServer
  use TypeCheck

  alias UpdateServer.Boundary.CoordinatorAdjunct

  @type! server() :: String.t()
  @type! ordinal() :: non_neg_integer()
  # conn is pid of UpdateServer.Boundary.Connection GenServer
  @type! servers() :: map(server(), {conn :: pid(), ordinal()})
  # reference() not yet supported by TypeCheck
  @type! state() :: {servers(), map(any(), server())}

  @moduledoc """
  GenServer for coordinating SSH connections to servers.

  Manages the list of servers and any needed bookkeeping. The
  `UpdateServer.Boundary.Connection` module actually manages
  the individual connections.
  """

  # Client

  @doc """
  Start `Coordinator` instance.
  """
  @spec start_link(any, GenServer.options()) :: GenServer.on_start()
  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, args, [{:name, __MODULE__} | opts])
  end

  @doc """
  Start SSH connection to server.
  """
  @spec! connect(server()) :: {:ok, ordinal()} | {:error, any()}
  def connect(server) do
    GenServer.call(__MODULE__, {:connect, server}, 30_000)
  end

  @doc """
  Disconnect connection to server.
  """
  @spec! disconnect(server()) :: :ok | {:error, any()}
  def disconnect(server) do
    GenServer.cast(__MODULE__, {:disconnect, server})
  end

  @doc """
  List servers, along with their ordinal shortcuts, that have an SSH connection.
  """
  @spec! list_servers() :: {:ok, list({server(), ordinal()}) | []}
  def list_servers() do
    GenServer.call(__MODULE__, :list_servers)
  end

  @doc """
  Send command to server.
  """
  @spec! send_to_session(server(), String.t()) :: :ok
  def send_to_session(server, command) do
    GenServer.cast(__MODULE__, {:send_to_session, server, command})
  end

  # Server

  @impl GenServer
  @spec init(any) ::
          {:ok, state}
          | {:ok, state, timeout() | :hibernate | {:continue, any()}}
          | :ignore
          | {:stop, any()}
  def init(_args) do
    servers = %{}
    refs = %{}
    {:ok, {servers, refs}}
  end

  @impl GenServer
  def handle_call({:connect, server}, _from, {servers, refs} = state) do
    case CoordinatorAdjunct.connect(servers, refs, server) do
      {ord, servers, refs} ->
        {:reply, {:ok, ord}, {servers, refs}}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_servers, _from, {servers, _refs} = state) do
    server_list = CoordinatorAdjunct.list_servers(servers)

    {:reply, {:ok, server_list}, state}
  end

  @impl GenServer
  def handle_cast({:disconnect, server}, {servers, _refs} = state) do
    CoordinatorAdjunct.disconnect(servers, server)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send_to_session, server, command}, {servers, _refs} = state) do
    CoordinatorAdjunct.send_to_session(servers, server, command)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:connection_closed, server, _message}, {servers, refs}) do
    {servers, refs} = CoordinatorAdjunct.remove_server(servers, refs, server)

    {:noreply, {servers, refs}}
  end

  @impl GenServer
  def handle_info({:command, server, message}, state) do
    CoordinatorAdjunct.publish(server, message)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:data, server, message}, state) do
    CoordinatorAdjunct.publish(server, message)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:eof, server, message}, state) do
    CoordinatorAdjunct.publish(server, message)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:exit_status, server, message}, state) do
    CoordinatorAdjunct.publish(server, message)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    IO.puts("Unexpected message in Coordinator: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, _state) do
    IO.puts("Terminating: #{inspect(reason)}")
  end
end
