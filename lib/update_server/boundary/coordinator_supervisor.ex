defmodule UpdateServer.Boundary.CoordinatorSupervisor do
  use Supervisor

  alias UpdateServer.Boundary.{ConnectionSupervisor, Coordinator, PubSub}

  @moduledoc """
  Supervisor for managing the `UpdateServer.Boundary.PubSub`,
  `UpdateServer.Boundary.ConnectionSupervisor`,
  and `UpdateServer.Boundary.Coordinator` instances.
  """

  @spec start_link(any, [{:name, atom | {:global, any} | {:via, atom, any}}]) ::
          :ignore | {:error, any} | {:ok, pid}
  def start_link(args \\ [], opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  @impl true
  @spec init(any()) :: {:ok, {:supervisor.sup_flags(), [Supervisor.child_spec()]}} | :ignore
  def init(_args) do
    children = [
      PubSub,
      ConnectionSupervisor,
      Coordinator
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
