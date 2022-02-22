defmodule UpdateServer.Boundary.PubSub do
  use GenServer
  use TypeCheck

  @type! server() :: String.t()
  @type! full_message() :: {message_type :: atom(), message :: String.t()}
  @type! channels() ::
           map(
             atom() | server(),
             MapSet.t() | {MapSet.t(), [full_message()]}
           )

  @moduledoc """
  Manages messages between command line, connections, and the UI.

  The module maintains a collection of channels.
  Each channel contains a list of members and messages.
  Messages sent to a channel get sent to each member.
  Each server has a channel.
  """

  # Client

  @doc """
  Start `PubSub` instance.
  """
  @spec start_link(any, [
          {:debug, [:log | :statistics | :trace | {any, any}]}
          | {:hibernate_after, :infinity | non_neg_integer}
          | {:name, atom | {:global, any} | {:via, atom, any}}
          | {:spawn_opt, [:link | :monitor | {any, any}]}
          | {:timeout, :infinity | non_neg_integer}
        ]) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, args, [{:name, __MODULE__} | opts])
  end

  @doc """
  Add a channel for server.

  Publishes the new channel to all other channels.
  """
  @spec! add_channel(server()) :: :ok
  def add_channel(server) do
    GenServer.cast(__MODULE__, {:add_channel, server})
  end

  @doc """
  Publish message to channel's (i.e. server's) members.
  """
  @spec! publish(server(), full_message()) :: :ok
  def publish(server, message) do
    if !is_nil(message) do
      GenServer.cast(__MODULE__, {:publish, server, message})
    end
  end

  @doc """
  Refresh channel's messages.
  """
  @spec! refresh(server()) :: :ok
  def refresh(server) do
    GenServer.cast(__MODULE__, {:refresh, server})
  end

  @doc """
  Remove channel from channel collection.
  """
  @spec! remove_channel(server()) :: :ok
  def remove_channel(server) do
    GenServer.cast(__MODULE__, {:remove_channel, server})
  end

  @doc """
  Subscribe (i.e. become a member) of a channel.
  """
  @spec! subscribe(server() | atom()) :: :ok
  def subscribe(server) do
    GenServer.cast(__MODULE__, {:subscribe, self(), server})
  end

  @doc """
  Unsubscribe from a channel.
  """
  @spec! unsubscribe(server()) :: :ok
  def unsubscribe(server) do
    GenServer.cast(__MODULE__, {:unsubscribe, self(), server})
  end

  # Server

  @impl GenServer
  @spec init(any) :: {:ok, %{channels_quantity_change: MapSet.t()}}
  def init(_init_arg) do
    channels = %{channels_quantity_change: %MapSet{}}

    {:ok, channels}
  end

  @impl GenServer
  def handle_cast({:add_channel, server}, channels) do
    channels =
      channels
      |> Map.put_new(server, {%MapSet{}, []})

    for member <- Map.get(channels, :channels_quantity_change, []) do
      send(member, {:add_channel, server})
    end

    {:noreply, channels}
  end

  @impl GenServer
  def handle_cast({:publish, server, message}, channels) do
    channels = add_message_to_channel(channels, server, message)

    {members, messages} = Map.get(channels, server)

    for member <- members do
      send(member, {:server_data, messages})
    end

    {:noreply, channels}
  end

  @impl GenServer
  def handle_cast({:refresh, server}, channels) do
    {members, messages} = Map.get(channels, server, {[], []})

    for member <- members do
      send(member, {:server_data, messages})
    end

    {:noreply, channels}
  end

  @impl GenServer
  def handle_cast({:remove_channel, server}, channels) do
    channels = Map.delete(channels, server)

    for member <- Map.get(channels, :channels_quantity_change, []) do
      send(member, {:remove_channel, server})
    end

    {:noreply, channels}
  end

  @impl GenServer
  def handle_cast({:subscribe, member, :channels_quantity_change}, channels) do
    channels =
      Map.update!(
        channels,
        :channels_quantity_change,
        fn members -> MapSet.put(members, member) end
      )

    {:noreply, channels}
  end

  @impl GenServer
  def handle_cast({:subscribe, member, server}, channels) do
    channels =
      Map.update!(
        channels,
        server,
        fn {members, message} ->
          {MapSet.put(members, member), message}
        end
      )

    {:noreply, channels}
  end

  @impl GenServer
  def handle_info(msg, state) do
    IO.puts("Unexpected message in PubSub: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec! add_message_to_channel(channels(), server(), full_message()) :: channels()
  defp add_message_to_channel(channels, server, message) do
    {members, messages} = Map.get(channels, server, {%MapSet{}, []})

    messages = [message | messages]

    Map.put(channels, server, {members, messages})
  end
end
