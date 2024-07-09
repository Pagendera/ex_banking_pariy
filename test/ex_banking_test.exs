defmodule ExBankingTest do
  use ExUnit.Case

  describe "create_user/1" do
    test "creates a new user" do
      assert ExBanking.create_user("John") == :ok
    end

    test "returns an error if the user already exists" do
      ExBanking.create_user("Jane")
      assert ExBanking.create_user("Jane") == {:error, :user_already_exists}
    end

    test "returns an error for invalid arguments" do
      assert ExBanking.create_user(nil) == {:error, :wrong_arguments}
      assert ExBanking.create_user(213) == {:error, :wrong_arguments}
    end
  end

  describe "get_balance/2" do
    setup do
      ExBanking.create_user("Alice")
      :ok
    end

    test "returns the balance for an existing user" do
      assert ExBanking.get_balance("Alice", "USD") == {:ok, 0.0}
    end

    test "returns an error if the user does not exist" do
      assert ExBanking.get_balance("Bob", "USD") == {:error, :user_does_not_exist}
    end

    test "returns an error for invalid arguments" do
      assert ExBanking.get_balance(nil, "USD") == {:error, :wrong_arguments}
      assert ExBanking.get_balance("Alice", nil) == {:error, :wrong_arguments}
    end
  end

  describe "deposit/3" do
    setup do
      ExBanking.create_user("Charlie")
      :ok
    end

    test "deposits the amount for an existing user" do
      assert ExBanking.deposit("Charlie", 100.0, "USD") == {:ok, 100.0}
    end

    test "returns an error if the user does not exist" do
      assert ExBanking.deposit("Bob", 100.0, "USD") == {:error, :user_does_not_exist}
    end

    test "returns an error for invalid arguments" do
      assert ExBanking.deposit(nil, 100.0, "USD") == {:error, :wrong_arguments}
      assert ExBanking.deposit("Charlie", -100.0, "USD") == {:error, :wrong_arguments}
    end
  end

  describe "withdraw/3" do
    setup do
      ExBanking.create_user("Dave")
      :ok
    end

    test "withdraws the amount for an existing user" do
      ExBanking.deposit("Dave", 100.0, "USD")
      assert ExBanking.withdraw("Dave", 50.0, "USD") == {:ok, 50.0}
    end

    test "returns an error if the user does not exist" do
      assert ExBanking.withdraw("Bimba", 50.0, "USD") == {:error, :user_does_not_exist}
    end

    test "returns an error for insufficient balance" do
      assert ExBanking.withdraw("Dave", 150.0, "USD") == {:error, :not_enough_money}
    end

    test "returns an error for invalid arguments" do
      assert ExBanking.withdraw(nil, 50.0, "USD") == {:error, :wrong_arguments}
      assert ExBanking.withdraw("Dave", -50.0, "USD") == {:error, :wrong_arguments}
    end
  end

  describe "send/4" do
    setup do
      ExBanking.create_user("Eve")
      ExBanking.create_user("Frank")
      :ok
    end

    test "sends the amount from one user to another" do
      ExBanking.deposit("Eve", 100.0, "USD")
      assert ExBanking.send("Eve", "Frank", 50.0, "USD") == {:ok, 50.0, 50.0}
    end

    test "returns an error if the sender does not exist" do
      assert ExBanking.send("NonExistent", "Frank", 50.0, "USD") == {:error, :sender_does_not_exist}
    end

    test "returns an error if the receiver does not exist" do
      assert ExBanking.send("Eve", "NonExistent", 50.0, "USD") == {:error, :receiver_does_not_exist}
    end

    test "returns an error for insufficient balance" do
      assert ExBanking.send("Eve", "Frank", 150.0, "USD") == {:error, :not_enough_money}
    end

    test "returns an error for invalid arguments" do
      assert ExBanking.send(nil, "Frank", 50.0, "USD") == {:error, :wrong_arguments}
      assert ExBanking.send("Eve", nil, 50.0, "USD") == {:error, :wrong_arguments}
      assert ExBanking.send("Eve", "Frank", -50.0, "USD") == {:error, :wrong_arguments}
    end
  end

  describe "performance" do
    test "too many deposits" do
      ExBanking.create_user("Olivia")

      responses_list =
        1..15
        |> Enum.map(fn _ -> Task.async(fn -> ExBanking.deposit("Olivia", 100, "USD") end) end)
        |> Enum.map(&Task.await(&1))

      assert Enum.member?(responses_list, {:error, :too_many_requests_to_user}) == true
    end

    test "too many withdraws" do
      ExBanking.create_user("Peter")
      ExBanking.deposit("Peter", 10000, "USD")

      responses_list =
        1..15
        |> Enum.map(fn _ -> Task.async(fn -> ExBanking.withdraw("Peter", 100, "USD") end) end)
        |> Enum.map(&Task.await(&1))

      assert Enum.member?(responses_list, {:error, :too_many_requests_to_user}) == true
    end

    test "too many requests to sender" do
      ExBanking.create_user("Quinn")
      ExBanking.deposit("Quinn", 10000, "USD")
      ExBanking.create_user("Rachel")
      ExBanking.create_user("Sophie")

      responses_list =
        1..15
        |> Enum.map(fn i ->
          Task.async(fn ->
            if i > 7 do
              ExBanking.send("Quinn", "Rachel", 100, "USD")
            else
              ExBanking.send("Quinn", "Sophie", 100, "USD")
            end
          end)
        end)
        |> Enum.map(&Task.await(&1))

      assert Enum.member?(responses_list, {:error, :too_many_requests_to_sender}) == true
    end

    test "too many requests to receiver" do
      ExBanking.create_user("Tom")
      ExBanking.create_user("Uma")
      ExBanking.create_user("Vera")
      ExBanking.deposit("Tom", 10000, "USD")
      ExBanking.deposit("Uma", 10000, "USD")
      ExBanking.deposit("Vera", 10000, "USD")
      ExBanking.create_user("Walter")

      responses_list =
        1..19
        |> Enum.map(fn i ->
          Task.async(fn ->
            cond do
              i < 7 -> ExBanking.send("Tom", "Walter", 100, "USD")
              i < 14 -> ExBanking.send("Uma", "Walter", 100, "USD")
              true -> ExBanking.send("Vera", "Walter", 100, "USD")
            end
          end)
        end)
        |> Enum.map(&Task.await(&1))

      assert Enum.member?(responses_list, {:error, :too_many_requests_to_receiver}) == true
    end
  end
end
