defmodule Annex.DataTest do
  alias Annex.{
    AnnexError,
    Data,
    Data.DMatrix,
    Data.List1D,
    Data.List2D,
    Layer.Dense
  }

  alias AnnexHelpers.SimpleData

  require Data

  @data_3 [1.0, 2.0, 3.0]
  @simple_3 SimpleData.cast(@data_3, [3])

  @data_4_by_5 [
    [1.0, 2.0, 3.0, 4.0],
    [5.0, 6.0, 7.0, 8.0],
    [9.0, 10.0, 11.0, 12.0],
    [13.0, 14.0, 15.0, 16.0],
    [17.0, 18.0, 19.0, 20.0]
  ]
  @simple_4_by_5 @data_4_by_5 |> List.flatten() |> SimpleData.cast([4, 5])

  @data_2_by_3 [
    [1.0, 2.0, 3.0],
    [4.0, 5.0, 6.0]
  ]
  @simple_2_by_3 @data_2_by_3
                 |> List.flatten()
                 |> SimpleData.cast([2, 3])

  @casts [
    {@simple_3, [3], [3]},
    {@simple_4_by_5, [4, 5], [4, 5]},
    {@simple_4_by_5, [4, 5], [20]},
    {@simple_4_by_5, [4, 5], [20, 1]},
    {@simple_4_by_5, [4, 5], [5, 4]},
    {%SimpleData{internal: [2.0, 3.0, 4.0, 5.0], shape: [4]}, [4], [2, 2]}
  ]

  use Annex.DataCase, type: SimpleData, data: @casts
  use Annex.LayerCase

  describe "cast/2" do
    test "calls cast for implementers of behaviour" do
      data = [1.0, 2.0, 3.0]
      shape = [3, 1]

      data = %SimpleData{
        internal: data,
        shape: shape
      }

      assert Data.cast(data, shape) == data
    end
  end

  describe "cast/3" do
    test "raises for empty list shape" do
      data = [1.0, 2.0, 3.0]
      assert_raise(AnnexError, fn -> Data.cast(SimpleData, data, []) end)
    end

    test "raises for nil shape" do
      data = [1.0, 2.0, 3.0]
      assert_raise(FunctionClauseError, fn -> Data.cast(SimpleData, data, nil) end)
    end

    test "calls cast for implementers of behaviour" do
      data = [1.0, 2.0, 3.0]
      shape = [3, 1]

      expected_data = %SimpleData{
        internal: data,
        shape: shape
      }

      assert Data.cast(SimpleData, data, shape) == expected_data
    end
  end

  describe "to_flat_list/2" do
    test "works" do
      simple = %SimpleData{
        internal: [3.0, 2.0, 1.0],
        shape: [3]
      }

      assert Data.to_flat_list(SimpleData, simple) == [3.0, 2.0, 1.0]
    end

    test "errors for non-implementers of Enumerable" do
      simple = %SimpleData{
        internal: [3.0, 2.0, 1.0]
      }

      assert Data.to_flat_list(SimpleData, simple) == [3.0, 2.0, 1.0]
    end
  end

  describe "convert/3" do
    test "makes no changes given the same shape" do
      assert Data.convert(SimpleData, @simple_2_by_3, [2, 3]) == @simple_2_by_3
    end

    test "converts given a compatible concrete shape" do
      assert Data.convert(SimpleData, @simple_2_by_3, [3, 2]) == %SimpleData{
               internal: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
               shape: [3, 2]
             }
    end

    test "converts given a compatible abstract shape" do
      assert Data.convert(SimpleData, @simple_2_by_3, [6, :any]) == %SimpleData{
               internal: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
               shape: [6, 1]
             }
    end

    test "converts correctly given :any as the first element of the shape" do
      assert Data.convert(SimpleData, @simple_2_by_3, [:any, 3]) == %SimpleData{
               internal: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
               shape: [2, 3]
             }
    end

    test "raises for an incompatible shape" do
      assert_raise(AnnexError, fn ->
        Data.convert(SimpleData, @simple_2_by_3, [20, 3])
      end)

      assert_raise(AnnexError, fn ->
        Data.convert(SimpleData, @simple_2_by_3, [1, 3])
      end)
    end
  end

  describe "infer_type/1" do
    test "List1D for flat list of floats" do
      data = [1.0, 2.0]
      assert Data.infer_type(data) == List1D
    end

    test "List2D for flat list of floats" do
      data = [[1.0, 2.0]]
      assert Data.infer_type(data) == List2D
    end

    test "works for SimpleData data" do
      assert Data.infer_type(@simple_2_by_3) == AnnexHelpers.SimpleData
    end

    test "works for DMatrix data" do
      assert [1.0, 2.0, 3.0]
             |> DMatrix.build()
             |> Data.infer_type() == DMatrix
    end

    test "works for Layer" do
      assert Dense
             |> build(rows: 2, columns: 3)
             |> Data.infer_type() == DMatrix
    end

    test "raises for empty list" do
      assert_raise(AnnexError, fn -> Data.infer_type([]) end)
    end
  end

  describe "data_type/1" do
    test "a built Dense layer defaults data_type to DMatrix" do
      assert %Dense{data_type: DMatrix} = build(Dense, rows: 3, columns: 2)
    end
  end

  describe "is_flat_data/1 guard" do
    test "can be used as a guard" do
      case Enum.random([[1.0], [2.0]]) do
        x when Data.is_flat_data(x) -> assert true
        _ -> assert false, "is_flat_data guard did not work on flat data"
      end
    end
  end
end
