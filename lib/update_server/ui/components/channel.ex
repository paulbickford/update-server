defmodule UpdateServer.UI.Component.Channel do
  use Scenic.Component
  # use TypeCheck
  # TypeCheck complains that Scenic.Scene.t() and Scenic.Graph.t() are undefined or private
  require Logger

  import Scenic.Components
  import Scenic.Primitives

  alias Scenic.Graph
  alias Scenic.Primitive.Style.Theme
  alias UpdateServer.Boundary.PubSub

  @type color() ::
          {red :: integer, green :: integer, blue :: integer}
          | {red :: integer, green :: integer, blue :: integer, alpha :: integer}
          | atom
  @type message() :: {message_type :: atom, message :: String.t()}
  @type text_specs() :: %{(line_number :: integer()) => any()} | %{}

  @moduledoc """
  Creates and manages a UI component for each channel.

  Creates and manages scrolling bar.
  """

  # Colors
  @background_color {48, 48, 48}
  @command_color :light_blue
  @data_color :white
  @control_color :peach_puff
  @header_background_color {50, 0, 0}
  @header_font_color {255, 251, 125}

  # ID suffixes
  @id_suffix_scroll "-scroll"
  @id_suffix_text "-text"

  @font :roboto_mono
  @font_size 16

  @header_height @font_size * 1.5
  @indent 30
  @outline_stroke {1, {:color, :black}}
  @scroll_width 18
  @text_color %{
    :control => @control_color,
    :command => @command_color,
    :data => @data_color
  }

  @impl Scenic.Component
  def validate({server, top, height})
      when is_bitstring(server) and
             is_integer(top) and is_integer(height),
      do: {:ok, {server, top, height}}

  def validate(_), do: :invalid_data

  @impl Scenic.Scene
  def init(scene, {server, ordinal, height}, opts) do
    scene =
      scene
      |> assign(
        graph: nil,
        height: height,
        id: server,
        text_specs: %{},
        opts: opts,
        ordinal: ordinal,
        server: server,
        top: ordinal * height
      )

    graph = build_graph(scene)

    scene =
      scene
      |> assign(graph: graph)
      |> push_graph(graph)

    PubSub.subscribe(server)
    PubSub.refresh(server)

    {:ok, scene}
  end

  @impl Scenic.Scene
  def handle_event(
        {:value_changed, id_event, value} = event,
        _,
        %{assigns: %{graph: graph, id: id}} = scene
      ) do
    id_scroll = id <> @id_suffix_scroll

    case id_event do
      ^id_scroll ->
        graph = modify_text(graph, value, scene)

        scene =
          scene
          |> assign(graph: graph)
          |> push_graph(graph)

        {:halt, scene}

      _ ->
        {:cont, event, scene}
    end
  end

  @impl GenServer
  def handle_info({:server_data, messages}, scene) do
    scene =
      scene
      |> assign(text_specs: create_text_specs(messages))

    graph = build_graph(scene)

    scene =
      scene
      |> assign(graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  @impl GenServer
  def handle_info(
        {:resize, height, changed_ordinal},
        %{assigns: %{ordinal: ordinal}} = scene
      ) do
    ordinal =
      if ordinal <= changed_ordinal do
        ordinal
      else
        ordinal - 1
      end

    scene =
      scene
      |> assign(
        height: height,
        ordinal: ordinal,
        top: ordinal * height
      )

    graph = build_graph(scene)

    scene =
      scene
      |> assign(graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  @spec build_graph(Scenic.Scene.t()) :: Graph.t()
  defp build_graph(
         %{assigns: %{id: id, text_specs: text_specs, height: height, server: server, top: top}} =
           scene
       ) do
    {width, _vp_height} = scene.viewport.size
    window_line_size = window_line_size(height)
    scroll_index = scroll_max_index(text_specs, height)
    visible_text = visible_text_specs(text_specs, 0, window_line_size)

    hide_scrollbar? = window_line_size > Enum.count(text_specs)

    Graph.build(font: @font, font_size: @font_size, id: id)
    |> group(
      fn graph ->
        graph
        |> rect({width, @header_height}, fill: @header_background_color)
        |> text(server, fill: @header_font_color, translate: {@indent, @font_size * 1.1})
        |> rect({width - @scroll_width, height - @header_height},
          fill: @background_color,
          stroke: @outline_stroke,
          translate: {0, @header_height}
        )
        |> add_specs_to_graph(visible_text,
          id: id <> @id_suffix_text,
          translate: {@indent, @header_height + @font_size * 1.5}
        )
        |> slider({{0, scroll_index}, 0},
          hidden: hide_scrollbar?,
          id: id <> @id_suffix_scroll,
          rotate: -1.57,
          theme:
            Map.merge(Theme.normalize(:dark), %{
              text: @header_font_color,
              background: @background_color,
              border: :black,
              active: :blue,
              thumb: :slate_gray,
              focus: :green,
              highlight: :white
            }),
          translate: {width - @scroll_width, height},
          width: height - @header_height
        )
      end,
      translate: {0, top}
    )
  end

  @spec modify_text(Graph.t(), non_neg_integer(), Scenic.Scene.t()) :: Graph.t()
  defp modify_text(
         graph,
         scroll_start_index,
         %{assigns: %{height: height, id: id, text_specs: text_specs, top: top}}
       ) do
    window_line_size = window_line_size(height)
    text_id = id <> @id_suffix_text
    visible_text_specs = visible_text_specs(text_specs, scroll_start_index, window_line_size)

    graph
    |> Graph.delete(text_id)
    |> add_specs_to_graph(visible_text_specs,
      id: text_id,
      translate: {@indent, top + @header_height + @font_size * 1.5}
    )
  end

  @spec visible_text_specs(text_specs(), non_neg_integer(), non_neg_integer()) :: [
          Graph.deferred()
        ]
  defp visible_text_specs(text_specs, start_index, window_line_size) do
    for i <- (start_index + window_line_size)..start_index,
        spec = Map.get(text_specs, i) do
      spec
    end
  end

  @spec create_text_specs([message()] | []) :: text_specs()
  defp create_text_specs(messages) do
    message_list =
      messages
      |> Enum.map(&convert_message_to_lines(&1))
      |> List.flatten()
      |> Enum.map(&build_text_spec(&1))

    Enum.zip(0..(Enum.count(message_list) - 1), message_list)
    |> Enum.into(%{})
  end

  @spec build_text_spec({color(), String.t()}) :: (Graph.t() -> Graph.t())
  defp build_text_spec({color, text}) do
    text_spec(text, fill: color)
  end

  @spec convert_message_to_lines(message()) :: [{color(), String.t()}] | []
  defp convert_message_to_lines({data_type, text}) do
    lines = String.split(text, "\n")

    for line <- lines do
      {text_color(data_type), line <> "\n"}
    end
    |> Enum.reverse()
  end

  @spec text_color(atom()) :: color()
  defp text_color(data_type) do
    Map.get(@text_color, data_type, :white)
  end

  @spec window_line_size(non_neg_integer()) :: number()
  defp window_line_size(height) do
    h = height - @header_height

    floor(h / (@font_size * 1.5))
  end

  @spec scroll_max_index(text_specs(), non_neg_integer()) :: non_neg_integer()
  defp scroll_max_index(text_specs, height) do
    if window_line_size(height) < Enum.count(text_specs) do
      Enum.count(text_specs) - window_line_size(height)
    else
      1
    end
  end
end
