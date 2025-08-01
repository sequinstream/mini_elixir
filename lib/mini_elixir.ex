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
  def eval(code, module, function, args) when is_atom(module) and is_atom(function) and is_list(args) do
    with {:ok, ast} <- Code.string_to_quoted(code),
         :ok <- validate_module_name(ast, module),
        #  {:ok, module_body} <- extract_module_body(ast),
        #  :ok <- Validator.check(module_body),
        #  {:ok, {_fun_body, _arg_names}} <- unwrap_function(ast, function, length(args)) do

         {:ok, {fun_body, _arg_names}} <- unwrap_function(ast, function, length(args)),
         :ok <- Validator.check(fun_body) do
      try do
        # Only compile and execute after validation
        Code.compiler_options(ignore_module_conflict: true)
        Code.eval_quoted(ast)
        result = apply(module, function, args)
        {:ok, result}
      rescue
        e ->
          {:error, Exception.message(e)}
      after
        Code.compiler_options(ignore_module_conflict: false)
        :code.purge(module)
        :code.delete(module)
      end
    else
      {:error, reason} -> {:error, reason}
      {:error, line, reason} -> {:error, "Line #{line}: #{reason}"}
    end
  end

  defp validate_module_name({:defmodule, _, [{:__aliases__, _, module_parts}, _]}, expected_module) do
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

  defp extract_module_body({:defmodule, _, [_, [do: body]]}) do
    {:ok, body}
  end

  defp extract_module_body(_) do
    {:error, "Invalid module structure"}
  end

  defp unwrap_function({:defmodule, _, [_, [do: {:__block__, _, defs}]]}, expected_name, expected_arity) do
    # Handle multiple function definitions
    Enum.find_value(defs, {:error, "Function #{expected_name}/#{expected_arity} not found"}, fn
      {:def, _, [{name, _, args}, [do: body]]} when is_list(args) ->
        if name == expected_name and length(args) == expected_arity do
          arg_names = for {name, _, _} <- args, do: name
          {:ok, {body, arg_names}}
        end
      _ -> nil
    end)
  end

  defp unwrap_function({:defmodule, _, [_, [do: {:def, _, [{name, _, args}, [do: body]]}]]}, expected_name, expected_arity)
       when is_list(args) do
    cond do
      name != expected_name ->
        {:error, "Expected function name to be #{inspect(expected_name)}, got: #{inspect(name)}"}
      length(args) != expected_arity ->
        {:error, "Expected function arity to be #{expected_arity}, got: #{length(args)}"}
      true ->
        arg_names = for {name, _, _} <- args, do: name
        {:ok, {body, arg_names}}
    end
  end

  defp unwrap_function(_, _, _) do
    {:error, "Expected a module with function definition"}
  end
end
