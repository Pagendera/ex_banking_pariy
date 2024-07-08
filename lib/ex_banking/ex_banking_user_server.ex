defmodule ExBanking.ExBankingUserServer do
  use GenServer

  alias ExBanking.{UserSupervisor, ExBankingValidator}

  def start_link(user_name) do
    GenServer.start_link(__MODULE__, %{}, name: {:global, user_name})
  end

  def init(state) do
    {:ok, state}
  end

  def create_user(user) do
    with true <- ExBankingValidator.valid_arguments?(user),
      [] <- ExBankingValidator.check_user(user) do

        UserSupervisor.start_child(user)
        :ok
    else
      false -> {:error, :wrong_arguments}
      _ -> {:error, :user_already_exists}
    end
  end

  def get_balance(user, currency) do
    with true <- ExBankingValidator.valid_arguments?(user, currency),
      [{_user_name, user_pid}] <- ExBankingValidator.check_user(user),
      %{} = new_balance <- GenServer.call(user_pid, {:get_balance}) do

        ExBankingValidator.get_balance_from_state(new_balance, currency)
    else
      false -> {:error, :wrong_arguments}
      [] -> {:error, :user_does_not_exist}
    end
  end

  def deposit(user, amount, currency) do
    with true <- ExBankingValidator.valid_arguments?(user, amount, currency),
      [{_user_name, user_pid}] <- ExBankingValidator.check_user(user),
      %{} = new_balance <- GenServer.call(user_pid, {:deposit, amount, currency}) do

        ExBankingValidator.get_balance_from_state(new_balance, currency)
    else
      false -> {:error, :wrong_arguments}
      [] -> {:error, :user_does_not_exist}
    end
  end

  def withdraw(user, amount, currency) do
    with true <- ExBankingValidator.valid_arguments?(user, amount, currency),
      [{_user_name, user_pid}] <- ExBankingValidator.check_user(user),
      %{} = new_balance <- GenServer.call(user_pid, {:withdraw, amount, currency}) do

        ExBankingValidator.get_balance_from_state(new_balance, currency)
    else
      false -> {:error, :wrong_arguments}
      [] -> {:error, :user_does_not_exist}
      :not_enough_money -> {:error, :not_enough_money}
    end
  end

  def send(from_user, to_user, amount, currency) do
    with true <- ExBankingValidator.valid_arguments?(from_user, to_user, amount, currency) do
      from_user = ExBankingValidator.check_user(from_user)
      to_user = ExBankingValidator.check_user(to_user)

      cond do
        from_user == [] -> {:error, :sender_does_not_exist}
        to_user == [] -> {:error, :receiver_does_not_exist}
        true ->
          [{_from_name, from_pid}] = from_user
          [{_to_name, to_pid}] = to_user
          GenServer.call(from_pid, {:send, to_pid, amount, currency})
      end
    else
      false -> {:error, :wrong_arguments}
    end
  end

  def handle_call({:get_balance}, _from, state = %{})  do
    {:reply, state, state}
  end

  def handle_call({:deposit, amount, currency}, _from, state)  do
    new_state =
      state
      |> Map.update(currency, amount, fn balance -> (balance / 1 + amount / 1) |> Float.round(2) end)

    {:reply, new_state, new_state}
  end

  def handle_call({:withdraw, amount, currency}, _from, state) do
    with true <- ExBankingValidator.enough_balance?(state, currency, amount) do
      new_state =
        state
        |> Map.update(currency, amount, fn balance -> (balance / 1 - amount / 1) |> Float.round(2) end)

    {:reply, new_state, new_state}
    else
      false -> {:reply, :not_enough_money, state}
    end
  end

  def handle_call({:send, to_pid, amount, currency}, _from, state) do
    if ExBankingValidator.enough_balance?(state, currency, amount) do
      case GenServer.call(to_pid, {:deposit, amount, currency}) do
        %{^currency => to_new_balance} ->
          new_state =
            state
            |> Map.update(currency, amount, fn balance -> (balance / 1 - amount / 1) |> Float.round(2) end)

          {:ok, new_balance} = ExBankingValidator.get_balance_from_state(new_state, currency)
          {:reply, {:ok, new_balance, to_new_balance}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, :not_enough_money, state}
    end
  end
end
