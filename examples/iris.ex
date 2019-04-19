defmodule Annex.Examples.Iris do
  alias Annex.{Utils, Network, Layer}
  require Logger

  @floats ~w(sepal_length sepal_width petal_length petal_width)a
  @strings ~w(species)a

  @keys @floats ++ @strings

  NimbleCSV.define(IrisParser, separator: ",", escape: "\0")

  def cast({k, v}) when k in @floats do
    {k, String.to_float(v)}
  end

  def cast({k, v}) when k in @strings do
    {k, v}
  end

  def line_to_map(line) do
    [@keys, line]
    |> Enum.zip()
    |> Map.new(fn kv -> cast(kv) end)
  end

  def load do
    "./examples/iris.csv"
    |> File.stream!()
    |> IrisParser.parse_stream()
    |> Stream.drop(1)
    |> Stream.map(&line_to_map/1)
  end

  def species_to_label("setosa"), do: [1.0, 0.0, 0.0]
  def species_to_label("versicolor"), do: [0.0, 1.0, 0.0]
  def species_to_label("virginica"), do: [0.0, 0.0, 1.0]

  def prep_data(%Stream{} = data) do
    data
    |> normalize_by_name(:sepal_length)
    |> normalize_by_name(:sepal_width)
    |> normalize_by_name(:petal_length)
    |> normalize_by_name(:petal_width)
    |> Enum.map(&prep_row/1)
    |> Utils.split_dataset(0.12)
    |> case do
      {trains, tests} -> {Enum.unzip(trains), Enum.unzip(tests)}
    end
  end

  def normalize_by_name(dataset, name) do
    dataset
    |> Enum.map(fn item -> item[name] end)
    |> Utils.normalize()
    |> Enum.zip(dataset)
    |> Enum.map(fn {normalized, item} ->
      Map.put(item, name, normalized)
    end)
  end

  def prep_row(%{} = flower) do
    data = [
      flower.sepal_length,
      flower.sepal_width,
      flower.petal_length,
      flower.petal_width
    ]

    labels = species_to_label(flower.species)

    {data, labels}
  end

  def run do
    flower_data = load()
    {train_set, test_set} = prep_data(flower_data)

    {train_data, train_labels} = train_set
    {test_data, test_labels} = test_set

    Logger.debug(fn ->
      """
      Before:

      first test data: #{test_data |> List.first() |> inspect()}
      first test label #{test_labels |> List.first() |> inspect()}
      """
    end)

    seq1 =
      Annex.sequence(
        [
          Annex.dense(100, input_dims: 4),
          Annex.activation(:tanh),
          Annex.dense(3, input_dims: 100),
          Annex.activation(:sigmoid)
        ],
        learning_rate: 0.07,
        error_calc: fn p -> 2 * p + :rand.uniform() * 0.1 - 0.05 end
      )

    seq2 =
      Annex.train(seq1, train_data, train_labels,
        name: :iris,
        epochs: 10_000,
        print_at_epoch: 200
      )

    first_test_data = List.first(test_data)
    first_test_labels = List.first(test_labels)
    pred = Annex.predict(seq2, first_test_data)

    Logger.debug(fn ->
      """
      Done - :iris
      Data #{inspect(first_test_data)}
      Labels #{inspect(first_test_labels)}
      Pred #{inspect(pred)}
      """
    end)

    # {test_data, test_labels, seq2}

    test_data
    |> Enum.zip(test_labels)
    |> Enum.each(fn {datum, label} ->
      pred = Annex.predict(seq2, datum)
      norm = Utils.normalize(pred)

      correct? =
        norm
        |> Enum.zip(label)
        |> Enum.any?(fn {a, b} -> a == 1.0 and b == 1.0 end)

      Logger.debug(fn ->
        """
        TEST PRED:
          - datum: #{inspect(datum)}
          - label: #{inspect(label)}
          - pred: #{inspect(pred)}
          - norm: #{inspect(norm)}
          - correct?: #{inspect(correct?)}
        """
      end)
    end)
  end
end