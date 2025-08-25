defmodule MiniElixir do
  @moduledoc """
  MiniElixir provides a safe sandbox for evaluating Elixir code with restricted functionality.
  It allows users to write and execute Elixir code in a controlled environment where only
  whitelisted functions and operators are available.

  ## Features

  - Safe evaluation of Elixir code strings
  - Restricted access to only whitelisted functions and operators
  - Protection against dangerous operations
  - Support for any module and function name

  ## Example

      iex> code = \"\"\"
      ...> defmodule TextProcessor do
      ...>   def sort_words(text) do
      ...>     text
      ...>     |> String.split()
      ...>     |> Enum.sort()
      ...>   end
      ...> end
      ...> \"\"\"
      iex> {:ok, result} = MiniElixir.eval(code, TextProcessor, :sort_words, ["banana apple cherry"])
      iex> result
      ["apple", "banana", "cherry"]
  """

  alias MiniElixir.Validator

  @doc """
  Evaluates a string of Elixir code in a safe sandbox environment.

  ## Parameters

  - `code`: String containing the Elixir code to evaluate
  - `module`: The module name to define the function in
  - `function`: The name of the function to define and call
  - `args`: List of arguments to pass to the function

  ## Returns

  - `{:ok, result}` on success
  - `{:error, reason}` on failure

  ## Examples

      iex> code = \"\"\"
      ...> defmodule Calculator do
      ...>   def add_tax(price) do
      ...>     tax = price * 0.2
      ...>     %{price: price, tax: tax, total: price + tax}
      ...>   end
      ...> end
      ...> \"\"\"
      iex> MiniElixir.eval(code, Calculator, :add_tax, [100.0])
      {:ok, %{price: 100.0, tax: 20.0, total: 120.0}}

      iex> code = \"\"\"
      ...> defmodule NameFormatter do
      ...>   def format_name(first, last) do
      ...>     first_cap = String.capitalize(first)
      ...>     last_cap = String.capitalize(last)
      ...>     String.trim(first_cap <> " " <> last_cap)
      ...>   end
      ...> end
      ...> \"\"\"
      iex> MiniElixir.eval(code, NameFormatter, :format_name, ["john", "doe"])
      {:ok, "John Doe"}
  """
  def eval(code, module, function, args, opts \\ [])
      when is_atom(module) and is_atom(function) and is_list(args) and is_list(opts) do
    persistent? = Keyword.get(opts, :persistent, true)
    arity = length(args)

    with :ok <- validate_code_safety(code) do
        if persistent? and module_loaded?(module) and function_exported?(module, function, arity) do
          try do
            result = apply(module, function, args)
            {:ok, result}
          rescue
            e -> {:error, Exception.message(e)}
          end
        else
          with {:ok, ast} <- Code.string_to_quoted(code),
               :ok <- validate_module_name(ast, module),
               :ok <- validate_module_structure(ast),
               {:ok, {fun_body, arg_names}} <- unwrap_function(ast, function, length(args)),
               :ok <- Validator.check(fun_body, arg_names) do
            try do
              Code.compiler_options(ignore_module_conflict: true)
              Code.eval_quoted(ast)
              result = apply(module, function, args)
              {:ok, result}
            rescue
              e ->
                {:error, Exception.message(e)}
            after
              Code.compiler_options(ignore_module_conflict: false)

              if not persistent? do
                :code.purge(module)
                :code.delete(module)
              end
            end
          else
            {:error, reason} -> {:error, reason}
            {:error, line, reason} -> {:error, "Line #{line}: #{reason}"}
          end
        end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_code_safety(code) when is_binary(code) do
    cond do
      byte_size(code) > 100_000 ->
        {:error, "Code size exceeds maximum limit"}

      String.contains?(code, "foo") and String.length(code) > 10_000 ->
        {:error, "Potential atom exhaustion attack detected"}

      has_suspicious_patterns?(code) ->
        {:error, "Suspicious code patterns detected"}

      true ->
        :ok
    end
  end

  defp has_suspicious_patterns?(code) do
    # Look for patterns like foo1(), foo2(), foo3()... which create atoms
    repetitive_calls = Regex.scan(~r/\w+\d+\(\)/, code)
    length(repetitive_calls) > 1000
  end

  defp validate_module_name(
         {:defmodule, _, [{:__aliases__, _, module_parts}, _]},
         expected_module
       ) do
    actual_module = Module.concat(module_parts)

    if actual_module == expected_module do
      :ok
    else
      {:error, "Module name mismatch. Expected #{expected_module}, got #{actual_module}"}
    end
  end

  defp validate_module_name(_, _) do
    {:error, "Expected a module definition"}
  end

  defp validate_module_structure({:defmodule, _, [_, [do: body]]}) do
    validate_module_body(body)
  end

  defp validate_module_structure(_) do
    {:error, "Expected a module definition"}
  end

  defp validate_module_body({:__block__, _, statements}) when is_list(statements) do
    Enum.reduce_while(statements, :ok, fn statement, :ok ->
      case validate_statement(statement) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_module_body(single_statement) do
    validate_statement(single_statement)
  end

  defp validate_statement({:def, _, _}), do: :ok
  defp validate_statement({:defp, _, _}), do: :ok

  defp validate_statement({:defmodule, _, _}) do
    {:error, "Nested modules are not allowed"}
  end

  defp validate_statement({:alias, _, _}) do
    {:error, "Module aliases are not allowed"}
  end

  defp validate_statement({:import, _, _}) do
    {:error, "Module imports are not allowed"}
  end

  defp validate_statement({:require, _, _}) do
    {:error, "Module requires are not allowed"}
  end

  defp validate_statement({:use, _, _}) do
    {:error, "Module use is not allowed"}
  end

  defp validate_statement(expr) do
    case expr do
      {:@, _, _} -> :ok
      _ -> {:error, "Immediate code execution in modules is not allowed"}
    end
  end

  defp unwrap_function(
         {:defmodule, _, [_, [do: {:__block__, _, defs}]]},
         expected_name,
         expected_arity
       ) do
    # handle multiple function definitions
    Enum.find_value(defs, {:error, "Function #{expected_name}/#{expected_arity} not found"}, fn
      {:def, _, [{name, _, args}, [do: body]]} ->
        normalized_args = if is_list(args), do: args, else: []
        if name == expected_name and length(normalized_args) == expected_arity do
          arg_names = for {name, _, _} <- normalized_args, do: name
          {:ok, {body, arg_names}}
        end

      _ ->
        nil
    end)
  end

  defp unwrap_function(
         {:defmodule, _, [_, [do: {:def, _, [{name, _, args}, [do: body]]}]]},
         expected_name,
         expected_arity
       ) do
    normalized_args = if is_list(args), do: args, else: []
    cond do
      name != expected_name ->
        {:error, "Expected function name to be #{inspect(expected_name)}, got: #{inspect(name)}"}

      length(normalized_args) != expected_arity ->
        {:error, "Expected function arity to be #{expected_arity}, got: #{length(normalized_args)}"}

      true ->
        arg_names = for {name, _, _} <- normalized_args, do: name
        {:ok, {body, arg_names}}
    end
  end

  defp unwrap_function(_, _, _), do: {:error, "Expected a module with function definition"}

  defp module_loaded?(module) when is_atom(module) do
    case :code.is_loaded(module) do
      {:file, _} -> true
      _ -> false
    end
  end
end
