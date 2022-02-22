defmodule UpdateServer.Boundary.CoordinatorAdjunct do
  use TypeCheck

  alias UpdateServer.Boundary.{Connection, ConnectionSupervisor, PubSub}

  @type! server_name() :: String.t()
  # pid of UpdateServer.Boundary.Connection GenServer
  @type! conn() :: pid()
  @type! ordinal() :: non_neg_integer()
  @type! servers() :: map(server_name(), {conn(), ordinal()})

  @moduledoc """
  Helper functions for coordinating SSH connections.
  """

  @doc """
  Manages creating SSH connection to server.
  """
  @spec! connect(servers(), any(), server_name()) ::
           {ordinal(), servers(), any()} | {:error, any()}
  def connect(servers, refs, server_name) do
    with :error <- Map.fetch(servers, server_name),
         {:ok, conn} <- open_connection(server_name),
         :ok <- Connection.open_session(conn) do
      ref = Process.monitor(conn)
      refs = Map.put(refs, ref, server_name)
      ord = Enum.count(servers)
      servers = Map.put(servers, server_name, {conn, ord})

      PubSub.add_channel(server_name)

      {ord, servers, refs}
    else
      {:ok, {_conn, ord}} ->
        {ord, servers, refs}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Manages disconnection of SSH connection.
  """
  @spec! disconnect(servers(), server_name()) :: :ok | :error
  def disconnect(servers, server_name) do
    case Map.fetch(servers, server_name) do
      {:ok, {conn, _ord}} ->
        Connection.disconnect(conn)

      :error ->
        :error
    end
  end

  @doc """
  Create list of servers and their ordinal shortcuts.
  """
  @spec! list_servers(servers()) :: [{server_name(), ordinal()}] | []
  def list_servers(servers) do
    for {server_name, {_conn, ord}} <- servers do
      {server_name, ord}
    end
  end

  @doc """
  Publish message to server's `PubSub` channel.
  """
  @spec! publish(server_name(), {atom(), String.t()}) :: :ok
  def publish(server_name, message) do
    PubSub.publish(server_name, message)
  end

  @doc """
  Remove server from connected servers.
  """
  @spec! remove_server(servers(), any(), server_name()) :: {servers(), any()}
  def remove_server(servers, refs, server_name) do
    servers =
      servers
      |> Map.delete(server_name)
      |> recalc_ordinals()

    refs = Map.reject(refs, fn {_r, s} -> s == server_name end)

    PubSub.remove_channel(server_name)

    {servers, refs}
  end

  @doc """
  Send command to server.
  """
  @spec! send_to_session(servers(), server_name(), String.t()) :: any()
  def send_to_session(servers, server_name, command) do
    case Map.fetch(servers, server_name) do
      {:ok, {conn, _ord}} ->
        Connection.send_to_session(conn, command)

      _ ->
        nil
    end
  end

  @spec! open_connection(server_name()) :: {:ok, pid()} | {:ok, pid(), any()} | {:error, any()}
  defp open_connection(server_name) do
    ConnectionSupervisor.start_child(server_name)
  end

  @spec! recalc_ordinals(servers()) :: servers()
  defp recalc_ordinals(servers) do
    servers =
      servers
      |> Map.to_list()
      |> Enum.sort(fn {_ser1, {_con1, o1}}, {_ser2, {_con2, o2}} -> o1 < o2 end)
      |> Map.new()

    ords = 0..(Enum.count(servers) - 1)

    for {new_ord, {server_name, {conn, _ord}}} <- Enum.zip(ords, servers), into: %{} do
      {server_name, {conn, new_ord}}
    end
  end
end
