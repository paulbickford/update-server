defmodule UpdateServer.UI.Scene.Home do
  use Scenic.Scene
  require Logger
  import Scenic.Primitives

  alias Scenic.Graph
  alias UpdateServer.Boundary.PubSub
  alias UpdateServer.UI.Component.Channel

  @type server() :: String.t()
  @type ordinal() :: non_neg_integer()
  @type channels() :: %{server() => ordinal()}

  @moduledoc """
  Creates and manages the main UI window.
  """

  @font_size 16

  @impl Scenic.Scene
  def init(scene, _args, _opts) do
    {vp_width, _vp_height} = scene.viewport.size

    graph =
      Graph.build(font: :roboto, font_size: @font_size)
      |> text("Servers",
        font_size: @font_size,
        text_align: :center,
        translate: {vp_width / 2, @font_size}
      )

    scene =
      scene
      |> assign(
        graph: graph,
        channels: %{}
      )
      |> push_graph(graph)

    PubSub.subscribe(:channels_quantity_change)
    {:ok, scene}
  end

  @impl GenServer
  def handle_info(
        {:add_channel, server},
        %{assigns: %{channels: channels, graph: graph}} = scene
      ) do
    {_vp_width, vp_height} = scene.viewport.size

    ordinal = Enum.count(channels)
    new_channel_height = Integer.floor_div(vp_height, ordinal + 1)
    channels = Map.put(channels, server, ordinal)

    graph =
      graph
      |> Channel.add_to_graph({server, ordinal, new_channel_height}, id: server)

    scene =
      scene
      |> assign(
        graph: graph,
        channels: channels
      )
      |> push_graph(graph)

    if ordinal > 0 do
      send_children(scene, {:resize, new_channel_height, ordinal})
    end

    {:noreply, scene}
  end

  @impl GenServer
  def handle_info(
        {:remove_channel, server},
        %{assigns: %{channels: channels, graph: graph}} = scene
      ) do
    {_vp_width, vp_height} = scene.viewport.size

    case Map.fetch(channels, server) do
      {:ok, ordinal} ->
        channels = Map.delete(channels, server)

        number_channels =
          case Enum.count(channels) do
            n when n > 0 ->
              n

            _ ->
              1
          end

        new_channel_height = Integer.floor_div(vp_height, number_channels)

        graph =
          graph
          |> Graph.delete(server)

        scene =
          scene
          |> assign(
            graph: graph,
            channels: channels
          )
          |> push_graph(graph)

        if number_channels > 1 do
          send_children(scene, {:resize, new_channel_height, ordinal})
        end

        {:noreply, scene}

      :error ->
        {:noreply, scene}
    end
  end
end
