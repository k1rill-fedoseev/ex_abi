defmodule ABI.TypeDecoderTest do
  use ExUnit.Case, async: true

  doctest ABI.TypeDecoder

  alias ABI.FunctionSelector
  alias ABI.TypeDecoder
  alias ABI.TypeEncoder

  describe "decode" do
    test "successfully decodes positives and negatives integers" do
      positive_int = "000000000000000000000000000000000000000000000000000000000000002a"
      negative_int = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd8f1"

      result_to_decode =
        <<199, 158, 242, 32>> <> Base.decode16!(positive_int <> negative_int, case: :lower)

      selector = %FunctionSelector{
        function: "baz",
        method_id: <<199, 158, 242, 32>>,
        types: [
          {:int, 8},
          {:int, 256}
        ],
        returns: :int
      }

      result = [42, -9999]
      assert TypeDecoder.decode(result_to_decode, selector) == result

      assert TypeEncoder.encode(result, selector) ==
               result_to_decode
    end

    test "with string data" do
      types = [:string]
      result = ["dave"]
      assert result == TypeEncoder.encode(result, types) |> TypeDecoder.decode(types)
    end

    test "with dynamic array data" do
      types = [{:array, :address}]
      result = [[]]
      assert result == TypeEncoder.encode(result, types) |> TypeDecoder.decode(types)

      types = [{:array, :address}]
      result = [[<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 35>>]]
      encoded_result = TypeEncoder.encode(result, types)
      assert result == encoded_result |> TypeDecoder.decode(types)

      types = [{:array, :address}]

      result = [
        [
          <<11, 47, 94, 47, 60, 189, 134, 78, 170, 44, 100, 46, 55, 105, 193, 88, 35, 97, 202,
            246>>,
          <<170, 148, 182, 135, 211, 249, 85, 42, 69, 59, 129, 178, 131, 76, 165, 55, 120, 152,
            13, 192>>,
          <<49, 44, 35, 14, 125, 109, 176, 82, 36, 246, 2, 8, 166, 86, 227, 84, 28, 92, 66, 186>>
        ]
      ]

      encoded_pattern =
        """
        0000000000000000000000000000000000000000000000000000000000000020
        0000000000000000000000000000000000000000000000000000000000000003
        0000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6
        000000000000000000000000aa94b687d3f9552a453b81b2834ca53778980dc0
        000000000000000000000000312c230e7d6db05224f60208a656e3541c5c42ba
        """
        |> encode_multiline_string()

      encoded_result2 = TypeEncoder.encode(result, types)

      assert encoded_result2 == encoded_pattern
      assert result == encoded_result2 |> TypeDecoder.decode(types)
    end

    test "with dynamic tuple type" do
      types = [{:tuple, [:string]}]
      params = [{"Hello"}]

      expected_encoded_result =
        "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000548656c6c6f000000000000000000000000000000000000000000000000000000"
        |> encode_multiline_string()

      assert TypeDecoder.decode(expected_encoded_result, types) == params
      assert TypeEncoder.encode(params, types) == expected_encoded_result
    end

    test "with complex dynamic tuple type" do
      types = [{:tuple, [:string, :string, {:uint, 256}]}]
      params = [{"Hello", "Goodbye", 42}]

      expected_encoded_result =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000000548656c6c6f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007476f6f6462796500000000000000000000000000000000000000000000000000"
        |> encode_multiline_string()

      assert TypeDecoder.decode(expected_encoded_result, types) == params
      assert TypeEncoder.encode(params, types) == expected_encoded_result
    end

    test "with static tuple type" do
      types = [{:tuple, [{:uint, 256}]}]
      params = [{11}]

      expected_encoded_result =
        "000000000000000000000000000000000000000000000000000000000000000b"
        |> encode_multiline_string()

      assert TypeEncoder.encode(params, types) == expected_encoded_result
      assert TypeDecoder.decode(expected_encoded_result, types) == params
    end

    test "with dynamic array type" do
      types = [{:array, {:uint, 32}}]
      params = [[17, 1]]

      expected_encoded_result =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
        |> encode_multiline_string()

      assert TypeDecoder.decode(expected_encoded_result, types) == params
      assert TypeEncoder.encode(params, types) == expected_encoded_result
    end

    test "with static array type" do
      types = [{:array, {:uint, 32}, 2}]
      params = [[17, 1]]

      expected_encoded_result =
        "00000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
        |> encode_multiline_string()

      assert TypeDecoder.decode(expected_encoded_result, types) == params
      assert TypeEncoder.encode(params, types) == expected_encoded_result
    end

    test "with dynamic array in tuple" do
      types = [{:tuple, [{:array, {:uint, 32}}]}]
      params = [{[17, 1]}]

      expected_result =
        "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
        |> encode_multiline_string()

      assert TypeDecoder.decode(expected_result, types) == params
      assert TypeEncoder.encode(params, types) == expected_result
    end

    test "nested dynamic arrays example" do
      types = [{:array, {:array, {:uint, 256}}}, {:array, :string}]

      data =
        """
        0000000000000000000000000000000000000000000000000000000000000040
        0000000000000000000000000000000000000000000000000000000000000140
        0000000000000000000000000000000000000000000000000000000000000002
        0000000000000000000000000000000000000000000000000000000000000040
        00000000000000000000000000000000000000000000000000000000000000a0
        0000000000000000000000000000000000000000000000000000000000000002
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000002
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000003
        0000000000000000000000000000000000000000000000000000000000000003
        0000000000000000000000000000000000000000000000000000000000000060
        00000000000000000000000000000000000000000000000000000000000000a0
        00000000000000000000000000000000000000000000000000000000000000e0
        0000000000000000000000000000000000000000000000000000000000000003
        6f6e650000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000003
        74776f0000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000005
        7468726565000000000000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert [[[1, 2], [3]], ["one", "two", "three"]] ==
               TypeDecoder.decode(data, types)

      assert data ==
               data
               |> TypeDecoder.decode(types)
               |> TypeEncoder.encode(types)
    end

    test "with multiple arrays in tuple" do
      types = [{:tuple, [{:array, {:uint, 32}}, {:array, :string}]}]
      params = [{[17, 1], ["Hello"]}]

      expected_result =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000548656c6c6f000000000000000000000000000000000000000000000000000000"
        |> encode_multiline_string()

      assert TypeDecoder.decode(expected_result, types) == params
      assert TypeEncoder.encode(params, types) == expected_result
    end

    test "with a fixed-length array of static data" do
      data =
        """
        0000000000000000000000000000000000000000000000000000000000000007
        0000000000000000000000000000000000000000000000000000000000000003
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000005
        """
        |> encode_multiline_string()

      types = [{:array, {:uint, 256}, 6}]
      result = [[7, 3, 0, 0, 0, 5]]

      assert TypeDecoder.decode(data, types) == result
      assert TypeEncoder.encode(result, types) == data
    end

    test "with a fixed-length array of dynamic data" do
      types = [{:array, :string, 3}]
      result = [["foo", "bar", "baz"]]

      encoded_pattern =
        """
        0000000000000000000000000000000000000000000000000000000000000020
        0000000000000000000000000000000000000000000000000000000000000060
        00000000000000000000000000000000000000000000000000000000000000a0
        00000000000000000000000000000000000000000000000000000000000000e0
        0000000000000000000000000000000000000000000000000000000000000003
        666f6f0000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000003
        6261720000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000003
        62617a0000000000000000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      encoded_result = TypeEncoder.encode(result, types)
      assert encoded_result == encoded_pattern
      assert result == encoded_result |> TypeDecoder.decode(types)
    end

    test "with multiple types" do
      types = [
        {:uint, 256},
        {:array, {:uint, 32}},
        {:bytes, 10},
        :bytes
      ]

      encoded_pattern =
        """
        0000000000000000000000000000000000000000000000000000000000000123
        0000000000000000000000000000000000000000000000000000000000000080
        3132333435363738393000000000000000000000000000000000000000000000
        00000000000000000000000000000000000000000000000000000000000000e0
        0000000000000000000000000000000000000000000000000000000000000002
        0000000000000000000000000000000000000000000000000000000000000456
        0000000000000000000000000000000000000000000000000000000000000789
        000000000000000000000000000000000000000000000000000000000000000d
        48656c6c6f2c20776f726c642100000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      result = [0x123, [0x456, 0x789], "1234567890", "Hello, world!"]
      encoded_result = TypeEncoder.encode(result, types)
      assert encoded_result == encoded_pattern
      assert result == encoded_result |> TypeDecoder.decode(types)
    end

    test "with mixed multiple types" do
      types = [
        {:uint, 256},
        :string,
        {:uint, 8},
        :string
      ]

      encoded_data_bytes =
        """
        00000000000000000000000000000000000000000000000000000000000003e8
        0000000000000000000000000000000000000000000000000000000000000080
        0000000000000000000000000000000000000000000000000000000000000012
        00000000000000000000000000000000000000000000000000000000000000c0
        0000000000000000000000000000000000000000000000000000000000000003
        7473740000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000004
        5445535400000000000000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      result = [0x3E8, "tst", 0x12, "TEST"]
      assert TypeEncoder.encode(result, types) == encoded_data_bytes
      assert result == TypeEncoder.encode(result, types) |> TypeDecoder.decode(types)
    end

    test "with static tuple" do
      data =
        """
        0000000000000000000000000000000000000000000000000000000000000123
        3132333435363738393000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      result = [
        {0x123, "1234567890"}
      ]

      types = [{:tuple, [{:uint, 256}, {:bytes, 10}]}]

      assert TypeDecoder.decode(data, types) == result

      assert TypeEncoder.encode(result, types) == data
    end

    test "with dynamic tuple" do
      types = [{:tuple, [:bytes, {:uint, 256}, :string]}]
      result = [{"dave", 0x123, "Hello, world!"}]

      encoded_pattern =
        "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000012300000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000046461766500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d48656c6c6f2c20776f726c642100000000000000000000000000000000000000"
        |> encode_multiline_string()

      encoded_result = TypeEncoder.encode(result, types)
      assert encoded_result == encoded_pattern
      assert result == encoded_result |> TypeDecoder.decode(types)
    end

    # test "with the output of an executed contract" do
    #   encoded_pattern =
    #     """
    #     0000000000000000000000000000000000000000000000000000000000000007
    #     0000000000000000000000000000000000000000000000000000000000000003
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000005
    #     0000000000000000000000000000000000000000000000000000000000000001
    #     00000000000000000000000000000000000000000000012413b856370914a000
    #     00000000000000000000000000000000000000000000012413b856370914a000
    #     00000000000000000000000000000000000000000000000053444835ec580000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000003e73362871420000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000001
    #     0000000000000000000000000000000000000000000000000000000000000001
    #     0000000000000000000000000000000000000000000000000000000000000001
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000001
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000000000000000000000000
    #     0000000000000000000000000000000000000000000001212f67eff9a8ac801a
    #     0000000000000000000000000000000000000000000001212f67eff9a8ac8010
    #     0000000000000000000000000000000000000000000000000000000000000001
    #     0000000000000000000000000000000000000000000000000000000000000001
    #     0000000000000000000000000000000000000000000000000000000000000009
    #     436172746167656e610000000000000000000000000000000000000000000000
    #     """
    #     |> encode_multiline_string()

    #   expected = [
    #     [7, 3, 0, 0, 0, 5],
    #     true,
    #     [
    #       0x12413B856370914A000,
    #       0x12413B856370914A000,
    #       0x53444835EC580000,
    #       0,
    #       0x3E73362871420000,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0,
    #       0
    #     ],
    #     [
    #       true,
    #       true,
    #       true,
    #       false,
    #       true,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false,
    #       false
    #     ],
    #     0x1212F67EFF9A8AC801A,
    #     0x1212F67EFF9A8AC8010,
    #     1,
    #     1,
    #     "Cartagena"
    #   ]

    #   assert TypeDecoder.decode(encoded_pattern, [
    #            {:array, {:uint, 256}, 6},
    #            :bool,
    #            {:array, {:uint, 256}, 24},
    #            {:array, :bool, 24},
    #            {:uint, 256},
    #            {:uint, 256},
    #            {:uint, 256},
    #            {:uint, 256},
    #            :string
    #          ]) == expected
    # end

    test "with dynamic array data not at the beginning of types" do
      types = [:bool, {:array, :address}]
      result = [true, []]

      assert result == TypeEncoder.encode(result, types) |> TypeDecoder.decode(types)

      result = [true, [<<1::160>>]]
      assert result == TypeEncoder.encode(result, types) |> TypeDecoder.decode(types)
    end

    test "decodes output in selector without method_id" do
      data =
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0, 59, 97, 248, 178, 0, 124, 142, 234, 184, 234,
          10, 4, 155, 44, 145, 116, 185, 190, 83, 111, 130, 28, 39, 0, 46, 193, 26, 141, 114, 41,
          50, 198, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 192, 247, 128, 223, 195, 80, 117, 151, 155,
          13, 239, 88, 141, 153, 146, 37, 183, 236, 197, 111, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 82, 199, 57, 255, 68, 64, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 19, 1, 203, 241, 140, 96,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 178, 208, 94, 0, 123, 172, 27, 183, 206, 50, 211, 155, 191, 121, 147, 116, 6,
          204, 33, 141, 247, 135, 76, 46, 77, 208, 128, 179, 29, 66, 76, 66, 179, 106, 75, 167, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 192, 247, 128, 223, 195, 80, 117, 151, 155, 13, 239,
          88, 141, 153, 146, 37, 183, 236, 197, 111, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 82, 199, 57, 255, 68, 64, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 19, 1, 203, 241, 140, 96, 0>>

      selector = %ABI.FunctionSelector{
        function: "standardExits",
        input_names: ["exitIds"],
        inputs_indexed: nil,
        method_id: <<121, 75, 85, 147>>,
        returns: [
          array:
            {:tuple,
             [
               :bool,
               {:uint, 256},
               {:bytes, 32},
               :address,
               {:uint, 256},
               {:uint, 256},
               {:uint, 256}
             ]}
        ],
        type: :function,
        types: [array: {:uint, 168}]
      }

      expected_result = [
        [
          {true, 1_000_000_000,
           <<59, 97, 248, 178, 0, 124, 142, 234, 184, 234, 10, 4, 155, 44, 145, 116, 185, 190, 83,
             111, 130, 28, 39, 0, 46, 193, 26, 141, 114, 41, 50, 198>>,
           <<192, 247, 128, 223, 195, 80, 117, 151, 155, 13, 239, 88, 141, 153, 146, 37, 183, 236,
             197, 111>>, 1, 23_300_000_000_000_000, 5_350_000_000_000_000},
          {true, 3_000_000_000,
           <<123, 172, 27, 183, 206, 50, 211, 155, 191, 121, 147, 116, 6, 204, 33, 141, 247, 135,
             76, 46, 77, 208, 128, 179, 29, 66, 76, 66, 179, 106, 75, 167>>,
           <<192, 247, 128, 223, 195, 80, 117, 151, 155, 13, 239, 88, 141, 153, 146, 37, 183, 236,
             197, 111>>, 3, 23_300_000_000_000_000, 5_350_000_000_000_000}
        ]
      ]

      assert TypeDecoder.decode(data, selector, :output) == expected_result
    end

    test "decodes output in selector with method_id" do
      data =
        <<121, 75, 85, 147, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0, 59, 97, 248, 178, 0, 124,
          142, 234, 184, 234, 10, 4, 155, 44, 145, 116, 185, 190, 83, 111, 130, 28, 39, 0, 46,
          193, 26, 141, 114, 41, 50, 198, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 192, 247, 128, 223,
          195, 80, 117, 151, 155, 13, 239, 88, 141, 153, 146, 37, 183, 236, 197, 111, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 82, 199, 57,
          255, 68, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 19, 1, 203, 241, 140, 96, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 178, 208, 94, 0, 123, 172, 27, 183, 206, 50, 211,
          155, 191, 121, 147, 116, 6, 204, 33, 141, 247, 135, 76, 46, 77, 208, 128, 179, 29, 66,
          76, 66, 179, 106, 75, 167, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 192, 247, 128, 223, 195,
          80, 117, 151, 155, 13, 239, 88, 141, 153, 146, 37, 183, 236, 197, 111, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 82, 199, 57, 255, 68,
          64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 19, 1,
          203, 241, 140, 96, 0>>

      selector = %ABI.FunctionSelector{
        function: "standardExits",
        input_names: ["exitIds"],
        inputs_indexed: nil,
        method_id: <<121, 75, 85, 147>>,
        returns: [
          array:
            {:tuple,
             [
               :bool,
               {:uint, 256},
               {:bytes, 32},
               :address,
               {:uint, 256},
               {:uint, 256},
               {:uint, 256}
             ]}
        ],
        type: :function,
        types: [array: {:uint, 168}]
      }

      expected_result = [
        [
          {true, 1_000_000_000,
           <<59, 97, 248, 178, 0, 124, 142, 234, 184, 234, 10, 4, 155, 44, 145, 116, 185, 190, 83,
             111, 130, 28, 39, 0, 46, 193, 26, 141, 114, 41, 50, 198>>,
           <<192, 247, 128, 223, 195, 80, 117, 151, 155, 13, 239, 88, 141, 153, 146, 37, 183, 236,
             197, 111>>, 1, 23_300_000_000_000_000, 5_350_000_000_000_000},
          {true, 3_000_000_000,
           <<123, 172, 27, 183, 206, 50, 211, 155, 191, 121, 147, 116, 6, 204, 33, 141, 247, 135,
             76, 46, 77, 208, 128, 179, 29, 66, 76, 66, 179, 106, 75, 167>>,
           <<192, 247, 128, 223, 195, 80, 117, 151, 155, 13, 239, 88, 141, 153, 146, 37, 183, 236,
             197, 111>>, 3, 23_300_000_000_000_000, 5_350_000_000_000_000}
        ]
      ]

      assert TypeDecoder.decode(data, selector, :output) == expected_result
    end

    test "with the output of an executed contract (simplified)" do
      encoded_pattern =
        """
        0000000000000000000000000000000000000000000000000000000000000007
        0000000000000000000000000000000000000000000000000000000000000003
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000005
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000013243d4c58de80
        0000000000000000000000000000000000000000000000000013242f54119620
        000000000000000000000000000000000000000000000000000000000000001e
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000028
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000012f6c3c41bca38
        0000000000000000000000000000000000000000000000000016b1bbf11f79d8
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000001
        00000000000000000000000000000000000000000000000000000000000002c0
        0000000000000000000000000000000000000000000000000000000000000009
        436172746167656e610000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      expected = [
        [7, 3, 0, 0, 0, 5],
        true,
        [
          5_387_870_250_000_000,
          5_387_810_250_004_000,
          30,
          0,
          40
        ],
        [
          true,
          true,
          true,
          false,
          true
        ],
        5_337_870_250_003_000,
        6_387_870_250_007_000,
        1,
        1,
        "Cartagena"
      ]

      types = [
        {:array, {:uint, 256}, 6},
        :bool,
        {:array, {:uint, 256}, 5},
        {:array, :bool, 5},
        {:uint, 256},
        {:uint, 256},
        {:uint, 256},
        {:uint, 256},
        :string
      ]

      assert TypeDecoder.decode(encoded_pattern, types) == expected
      assert TypeEncoder.encode(expected, types) == encoded_pattern
    end

    test "sample from Solidity docs 1" do
      encoded_pattern =
        """
        000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000000848656c6c6f212521000000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      res =
        encoded_pattern
        |> TypeDecoder.decode(%FunctionSelector{
          function: nil,
          types: [
            {:tuple, [:string, {:uint, 256}]}
          ]
        })

      assert res == [{"Hello!%!", 34}]

      assert TypeEncoder.encode([{"Hello!%!", 34}], [
               {:tuple, [:string, {:uint, 256}]}
             ]) == encoded_pattern
    end

    test "simple non-trivial dynamic type offset" do
      types = [{:uint, 32}, :bytes]

      data =
        """
        0000000000000000000000000000000000000000000000000000000000000123
        0000000000000000000000000000000000000000000000000000000000000040
        000000000000000000000000000000000000000000000000000000000000000d
        48656c6c6f2c20776f726c642100000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert [0x123, "Hello, world!"] == TypeDecoder.decode(data, types)
      assert data == data |> TypeDecoder.decode(types) |> TypeEncoder.encode(types)
    end
  end

  describe "with examples from solidity docs" do
    # https://solidity.readthedocs.io/en/v0.5.13/abi-spec.html

    test "baz example" do
      types = [{:uint, 32}, :bool]

      data =
        """
        0000000000000000000000000000000000000000000000000000000000000045
        0000000000000000000000000000000000000000000000000000000000000001
        """
        |> encode_multiline_string()

      assert [69, true] == TypeDecoder.decode(data, types)
      assert data == data |> TypeDecoder.decode(types) |> TypeEncoder.encode(types)
    end

    test "bar example" do
      types = [{:array, {:bytes, 3}, 2}]

      data =
        """
        6162630000000000000000000000000000000000000000000000000000000000
        6465660000000000000000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert [["abc", "def"]] == TypeDecoder.decode(data, types)
      assert data == data |> TypeDecoder.decode(types) |> TypeEncoder.encode(types)
    end

    test "sam example" do
      types = [:bytes, :bool, {:array, {:uint, 32}}]

      data =
        """
        0000000000000000000000000000000000000000000000000000000000000060
        0000000000000000000000000000000000000000000000000000000000000001
        00000000000000000000000000000000000000000000000000000000000000a0
        0000000000000000000000000000000000000000000000000000000000000004
        6461766500000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000003
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000002
        0000000000000000000000000000000000000000000000000000000000000003
        """
        |> encode_multiline_string()

      assert ["dave", true, [1, 2, 3]] == TypeDecoder.decode(data, types)
      assert data == data |> TypeDecoder.decode(types) |> TypeEncoder.encode(types)
    end

    test "use of dynamic types example" do
      types = [{:uint, 32}, {:array, {:uint, 32}}, {:bytes, 10}, :bytes]

      data =
        """
        0000000000000000000000000000000000000000000000000000000000000123
        0000000000000000000000000000000000000000000000000000000000000080
        3132333435363738393000000000000000000000000000000000000000000000
        00000000000000000000000000000000000000000000000000000000000000e0
        0000000000000000000000000000000000000000000000000000000000000002
        0000000000000000000000000000000000000000000000000000000000000456
        0000000000000000000000000000000000000000000000000000000000000789
        000000000000000000000000000000000000000000000000000000000000000d
        48656c6c6f2c20776f726c642100000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert [0x123, [0x456, 0x789], "1234567890", "Hello, world!"] ==
               TypeDecoder.decode(data, types)

      assert data ==
               data
               |> TypeDecoder.decode(types)
               |> TypeEncoder.encode(types)
    end
  end

  defp encode_multiline_string(data) do
    data
    |> String.split("\n", trim: true)
    |> Enum.join()
    |> Base.decode16!(case: :mixed)
  end
end
