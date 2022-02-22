defmodule UpdateServer.Boundary.Connection do
  use GenServer, restart: :temporary
  use TypeCheck

  alias UpdateServer.Boundary.Coordinator

  @type! server_name() :: String.t()
  # pid of :ssh_connection_ref()
  @type! conn() :: pid()
  @type! channel() :: non_neg_integer()
  @type! data_type() :: atom()
  @type! state() :: %{
           server_name: server_name(),
           connection: conn(),
           channel: channel() | nil
         }

  @moduledoc """
  Manages SSH connection to a server.
  """

  # Client

  @doc """
  Starts `Connection` instance.
  """
  @spec start_link(any, GenServer.options()) :: GenServer.on_start()
  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Disconnects server.
  """
  @spec! disconnect(pid()) :: :ok | {:error, any()}
  def disconnect(pid) do
    GenServer.cast(pid, :disconnect)
  end

  @doc """
  Opens session with server.
  """
  @spec! open_session(pid) :: :ok | {:error, any}
  def open_session(pid) do
    GenServer.call(pid, :open_session, 30_000)
  end

  @doc """
  Sends command to server.
  """
  @spec! send_to_session(pid(), String.t()) :: :ok
  def send_to_session(pid, command) do
    GenServer.cast(pid, {:send_to_session, command})
  end

  # Server

  @impl GenServer
  @spec! init(server_name()) ::
           {:ok, state()}
           | {:ok, state(),
              :infinity | non_neg_integer() | :hibernate | {:continue, server_name()}}
           | :ignore
           | {:stop, any()}
  def init(server) do
    case :ssh.connect(String.to_charlist(server), 22, []) do
      {:ok, conn} ->
        {:ok, %{server_name: server, connection: conn, channel: nil}}

      _ ->
        {:stop, "Connection failed"}
    end
  end

  @impl GenServer
  def handle_call(:open_session, _from, state) do
    case :ssh_connection.session_channel(state.connection, :infinity) do
      {:ok, chan} ->
        state = %{state | channel: chan}
        :ssh_connection.shell(state.connection, state.channel)
        {:reply, :ok, state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_cast(:disconnect, state) do
    :ssh_connection.close(state.connection, state.channel)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send_to_session, command}, state) do
    :ssh_connection.send(state.connection, state.channel, '\n', 3000)

    case :ssh_connection.send(
           state.connection,
           state.channel,
           String.to_charlist(command),
           :infinity
         ) do
      :ok ->
        send(Coordinator, {:command, state.server_name, {:command, command}})

      _ ->
        IO.puts("Unknown response")
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:ssh_cm, _conn, {:closed, _ssh_chan}}, state) do
    send(
      Coordinator,
      {:connection_closed, state.server_name, {:control, "Session closed"}}
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {:ssh_cm, _conn, {:data, _ssh_chan, _std_out_or_err, data}},
        state
      ) do
    send(Coordinator, {:data, state.server_name, {:data, data}})

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:ssh_cm, _conn, {:eof, _ssh_chan}}, state) do
    send(Coordinator, {:eof, state.server_name, {:control, "EOF"}})

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:ssh_cm, _conn, {:exit_status, _ssh_chan, exit_status}}, state) do
    send(
      Coordinator,
      {:exit_status, state.server_name, {:control, "Exit status #{exit_status}"}}
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:ssh_cm, _conn, {:send, _ssh_chan, command}}, state) do
    send(Coordinator, {:command, state.server_name, {:command, command}})

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    IO.puts("Unexpected message in Connection: #{inspect(msg)}")

    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, _state) do
    IO.puts("Terminating: #{inspect(reason)}")
  end
end
