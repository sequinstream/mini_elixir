defmodule MiniElixirTest do
  use ExUnit.Case
  doctest MiniElixir

  describe "eval/4" do
    test "successfully evaluates a simple math function" do
      code = ~S"""
      defmodule Calculator do
        def add_tax(price) do
          tax = price * 0.2
          %{price: price, tax: tax, total: price + tax}
        end
      end
      """

      assert {:ok, result} = MiniElixir.eval(code, Calculator, :add_tax, [100.0])
      assert result == %{price: 100.0, tax: 20.0, total: 120.0}
    end

    test "successfully evaluates a recursive function" do
      code = ~S"""
      defmodule Math do
        def fibonacci(n) do
          case n do
            0 -> 0
            1 -> 1
            n -> fibonacci(n-1) + fibonacci(n-2)
          end
        end
      end
      """

      assert {:ok, 55} = MiniElixir.eval(code, Math, :fibonacci, [10])
    end

    test "successfully evaluates a string processing function" do
      code = ~S"""
      defmodule NameFormatter do
        def format_name(first, last) do
          String.trim("#{String.capitalize(first)} #{String.capitalize(last)}")
        end
      end
      """

      assert {:ok, "John Doe"} =
               MiniElixir.eval(code, NameFormatter, :format_name, ["john", "doe"])
    end

    test "handles complex data structures" do
      code = ~S"""
      defmodule ListProcessor do
        def process_list(items) do
          items
          |> Enum.map(&String.upcase/1)
          |> Enum.sort()
          |> Enum.with_index(1)
          |> Map.new(fn {item, idx} -> {idx, item} end)
        end
      end
      """

      assert {:ok, result} =
               MiniElixir.eval(code, ListProcessor, :process_list, [["banana", "apple", "cherry"]])

      assert result == %{1 => "APPLE", 2 => "BANANA", 3 => "CHERRY"}
    end

    test "rejects unsafe code" do
      code = ~S"""
      defmodule FileReader do
        def read_file(path) do
          File.read!(path)
        end
      end
      """

      assert {:error, _} = MiniElixir.eval(code, FileReader, :read_file, ["/etc/passwd"])
    end

    test "rejects code with wrong function name" do
      code = ~S"""
      defmodule Math do
        def add(x, y) do
          x + y
        end
      end
      """

      assert {:error, _} = MiniElixir.eval(code, Math, :sum, [1, 2])
    end

    test "rejects code with wrong arity" do
      code = ~S"""
      defmodule Greeter do
        def greet(name) do
          "Hello #{name}!"
        end
      end
      """

      assert {:error, _} = MiniElixir.eval(code, Greeter, :greet, ["John", "extra"])
    end

    test "rejects code trying to define modules" do
      code = ~S"""
      defmodule Evil do
        def evil(x) do
          defmodule Evil do
            def hack, do: System.cmd("rm", ["-rf", "/"])
          end
          x
        end
      end
      """

      assert {:error, _} = MiniElixir.eval(code, Evil, :evil, [1])
    end

    test "handles errors in user code" do
      code = ~S"""
      defmodule Math do
        def divide(a, b) do
          a / b  # This will raise an error if b is 0
        end
      end
      """

      assert {:error, message} = MiniElixir.eval(code, Math, :divide, [1, 0])
      assert is_binary(message)
    end

    test "allows using whitelisted modules" do
      code = ~S"""
      defmodule TextProcessor do
        def process_data(text) do
          %{
            "encoded" => Base.encode64(text),
            "length" => String.length(text),
            "words" => length(String.split(text)),
            "url_safe" => URI.encode(text)
          }
        end
      end
      """

      assert {:ok, result} = MiniElixir.eval(code, TextProcessor, :process_data, ["Hello World!"])
      assert is_binary(result["encoded"])
      assert result["length"] == 12
      assert result["words"] == 2
      assert is_binary(result["url_safe"])
    end

    test "prevents assigning to function arguments" do
      code = ~S"""
      defmodule Math do
        def increment(x) do
          x = x + 1  # This is not allowed
          x
        end
      end
      """

      assert {:error, _} = MiniElixir.eval(code, Math, :increment, [1])
    end

    test "prevents creating atoms from strings" do
      code = ~S"""
      defmodule Converter do
        def to_atom(str) do
          String.to_atom(str)
        end
      end
      """

      assert {:error, _} = MiniElixir.eval(code, Converter, :to_atom, ["dangerous"])
    end

    test "handles nested modules that override built-in modules" do
      code = ~S"""
      defmodule NameFormatterNested do
        defmodule String do
          def capitalize(a) do
            Code.eval_string(a, [])
          end
        end

        def format_name(first) do
          String.capitalize(first)
        end
      end
      """

      # Now this should be properly rejected due to nested module validation
      assert {:error, message} = MiniElixir.eval(code, NameFormatterNested, :format_name, ["john"])
      assert message =~ "Nested modules are not allowed"
    end

    test "handles module aliases" do
      code = ~S"""
      defmodule NameFormatterAlias do
        alias String, as: MyString

        def format_name(first) do
          MyString.capitalize(first)
        end
      end
      """

      # Now this should be properly rejected due to alias validation
      assert {:error, message} = MiniElixir.eval(code, NameFormatterAlias, :format_name, ["john"])
      assert message =~ "Module aliases are not allowed"
    end

    test "handles modules with immediate execution" do
      code = ~S"""
      defmodule NameFormatterIO do
        defmodule MyMod do
          IO.inspect("modules are tricky")
        end

        def format_name(first) do
          String.capitalize(first)
        end
      end
      """

      # Now this should be properly rejected due to nested module validation
      assert {:error, message} = MiniElixir.eval(code, NameFormatterIO, :format_name, ["john"])
      assert message =~ "Nested modules are not allowed"
    end

    test "prevents immediate code execution in modules" do
      code = ~S"""
      defmodule ImmediateExecution do
        IO.puts("This should not execute!")

        def safe_function(x) do
          x + 1
        end
      end
      """

      # This should be rejected due to immediate execution validation
      assert {:error, message} = MiniElixir.eval(code, ImmediateExecution, :safe_function, [1])
      assert message =~ "Immediate code execution in modules is not allowed"
    end
  end
end
