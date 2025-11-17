defmodule SingularityEdge.Balancer.Algorithm do
  @moduledoc """
  Load balancing algorithms for selecting backend servers.
  """

  alias SingularityEdge.Balancer.Backend

  @type algorithm :: :round_robin | :least_connections | :weighted_round_robin | :random

  @doc """
  Selects a backend using the specified algorithm.

  Returns `{:ok, backend}` if a healthy backend is available, `{:error, :no_backends}` otherwise.
  """
  @spec select([Backend.t()], algorithm(), map()) :: {:ok, Backend.t()} | {:error, :no_backends}
  def select(backends, algorithm, state \\ %{})

  def select([], _algorithm, _state), do: {:error, :no_backends}

  def select(backends, :round_robin, state) do
    healthy = Enum.filter(backends, & &1.healthy)

    case healthy do
      [] -> {:error, :no_backends}
      _ ->
        index = Map.get(state, :round_robin_index, 0)
        backend = Enum.at(healthy, rem(index, length(healthy)))
        {:ok, backend}
    end
  end

  def select(backends, :least_connections, _state) do
    healthy = Enum.filter(backends, & &1.healthy)

    case healthy do
      [] -> {:error, :no_backends}
      _ ->
        backend = Enum.min_by(healthy, & &1.current_connections)
        {:ok, backend}
    end
  end

  def select(backends, :weighted_round_robin, state) do
    healthy = Enum.filter(backends, & &1.healthy)

    case healthy do
      [] -> {:error, :no_backends}
      _ ->
        # Create weighted list (backend appears N times based on weight)
        weighted = Enum.flat_map(healthy, fn backend ->
          List.duplicate(backend, backend.weight)
        end)

        index = Map.get(state, :weighted_rr_index, 0)
        backend = Enum.at(weighted, rem(index, length(weighted)))
        {:ok, backend}
    end
  end

  def select(backends, :random, _state) do
    healthy = Enum.filter(backends, & &1.healthy)

    case healthy do
      [] -> {:error, :no_backends}
      _ ->
        backend = Enum.random(healthy)
        {:ok, backend}
    end
  end

  @doc """
  Updates the algorithm state after a selection (for stateful algorithms like round-robin).
  """
  @spec update_state(algorithm(), map()) :: map()
  def update_state(:round_robin, state) do
    Map.update(state, :round_robin_index, 1, &(&1 + 1))
  end

  def update_state(:weighted_round_robin, state) do
    Map.update(state, :weighted_rr_index, 1, &(&1 + 1))
  end

  def update_state(_algorithm, state), do: state
end
