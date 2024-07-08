defmodule ExBanking.Supervisor do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(:users, [:set, :public, :named_table])

    children = [
      {DynamicSupervisor, name: ExBanking.UserSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
