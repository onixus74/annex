defmodule Annex.Perceptron do
  alias Annex.{Perceptron, Utils}
  defstruct [:weights, :learning_rate, :activation, :bias]

  def new(inputs, activation, opts \\ []) when is_integer(inputs) and inputs > 0 do
    %Perceptron{
      weights: get_weights(inputs, opts),
      bias: Keyword.get(opts, :bias, 0.0),
      learning_rate: Keyword.get(opts, :learning_rate, 0.05),
      activation: get_activation(activation)
    }
  end

  defp get_activation(fun) when is_function(fun, 1) do
    fun
  end

  defp get_weights(inputs, opts) do
    case Keyword.get(opts, :weights) do
      weights when length(weights) == inputs -> weights
      _ -> Enum.map(1..inputs, fn _ -> 2 * :rand.uniform() - 1 end)
    end
  end

  def predict(%Perceptron{activation: activation, weights: weights, bias: bias}, inputs) do
    inputs
    |> Utils.dot(weights)
    |> Kernel.+(bias)
    |> activation.()
  end

  def train(%Perceptron{} = p, all_inputs, all_labels, opts \\ []) do
    epochs = Keyword.fetch!(opts, :epochs)

    all_inputs
    |> Utils.zip(all_labels)
    |> Stream.cycle()
    |> Stream.with_index()
    |> Stream.map(fn {{inputs, label}, index} -> {inputs, label, index} end)
    |> Enum.reduce_while(p, fn {inputs, label, index}, p_acc ->
      if index >= epochs do
        {:halt, p_acc}
      else
        {:cont, train_once(p_acc, inputs, label)}
      end
    end)
  end

  def train_once(%Perceptron{weights: weights, bias: bias, learning_rate: lr} = p, inputs, label) do
    prediction = predict(p, inputs)
    error = label - prediction
    slope_delta = error * lr

    weights =
      inputs
      |> Utils.zip(weights)
      |> Enum.map(fn {i, w} -> w + slope_delta * i end)

    %Perceptron{p | weights: weights, bias: bias + slope_delta}
  end
end