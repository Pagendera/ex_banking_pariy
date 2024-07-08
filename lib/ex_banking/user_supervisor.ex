defmodule ExBanking.UserSupervisor do
  use DynamicSupervisor

  alias ExBanking.ExBankingUserServer
  
  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(user_name) do
    case DynamicSupervisor.start_child(__MODULE__, {ExBankingUserServer, user_name}) do
      {:ok, pid} ->
        :ets.insert(:users, {user_name, pid})
        {:ok, pid}
      error -> error
    end
  end
end
