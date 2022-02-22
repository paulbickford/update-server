defmodule UpdateServer.UI.UISupervisor do
  use Supervisor
  require Logger

  @moduledoc """
  Supervisor manages UI.
  """

  @spec start_link(any, [{:name, atom | {:global, any} | {:via, atom, any}}]) ::
          :ignore | {:error, any} | {:ok, pid}
  def start_link(args \\ [], opts \\ []) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    main_viewport_config = Application.get_env(:update_server, :viewport)

    children = [
      {Scenic, [main_viewport_config]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
