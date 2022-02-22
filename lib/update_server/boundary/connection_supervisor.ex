defmodule UpdateServer.Boundary.ConnectionSupervisor do
  use DynamicSupervisor

  alias UpdateServer.Boundary.Connection

  @moduledoc """
  Supervisor for managing `UpdateServer.Boundary.Connection` instances.
  """

  @spec start_link(GenServer.options()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, [], [{:name, __MODULE__} | opts])
  end

  @spec start_child(any) :: :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def start_child(args) do
    DynamicSupervisor.start_child(__MODULE__, {Connection, args})
  end

  @impl true
  @spec init(any) :: {:ok, DynamicSupervisor.sup_flags()} | :ignore
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one, max_seconds: 60)
  end
end
