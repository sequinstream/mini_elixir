# MiniElixir

MiniElixir provides a safe sandbox for evaluating Elixir code with restricted functionality. It allows users to write and execute Elixir code in a controlled environment where only whitelisted functions and operators are available.

## Features

- Safe evaluation of Elixir code strings
- Restricted access to only whitelisted functions and operators
- Protection against dangerous operations
- Support for any module and function name
- Automatic cleanup after execution

## Installation

Add `mini_elixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mini_elixir, "~> 0.1.0"}
  ]
end
```

## Usage

MiniElixir allows you to safely evaluate Elixir code strings that define modules with functions. The module is automatically created, executed, and cleaned up after each evaluation.

### Basic Example

```elixir
code = """
defmodule Calculator do
  def add_tax(price) do
    tax = price * 0.2
    %{price: price, tax: tax, total: price + tax}
  end
end
"""

{:ok, result} = MiniElixir.eval(code, Calculator, :add_tax, [100.0])
# result = %{price: 100.0, tax: 20.0, total: 120.0}
```

### String Processing Example

```elixir
code = """
defmodule NameFormatter do
  def format_name(first, last) do
    String.trim("#{String.capitalize(first)} #{String.capitalize(last)}")
  end
end
"""

{:ok, result} = MiniElixir.eval(code, NameFormatter, :format_name, ["john", "doe"])
# result = "John Doe"
```

### Complex Data Processing Example

```elixir
code = """
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

{:ok, result} = MiniElixir.eval(code, ListProcessor, :process_list, [["banana", "apple", "cherry"]])
# result = %{1 => "APPLE", 2 => "BANANA", 3 => "CHERRY"}
```

## API Reference

### `MiniElixir.eval/4`

Evaluates a string of Elixir code in a safe sandbox environment.

```elixir
MiniElixir.eval(code, module, function, args) :: {:ok, result} | {:error, reason}
```

#### Parameters

- `code` (string): Elixir code string containing a module definition
- `module` (atom): The module name to define the function in
- `function` (atom): The name of the function to define and call
- `args` (list): List of arguments to pass to the function

#### Returns

- `{:ok, result}` on success
- `{:error, reason}` on failure

## Whitelisted Functions and Operators

MiniElixir provides access to a carefully selected set of safe functions and operators:

### Operators
- Arithmetic: `+`, `-`, `*`, `/`
- Comparison: `==`, `!=`, `===`, `!==`, `>`, `>=`, `<`, `<=`
- Logical: `&&`, `||`, `and`, `or`, `not`
- String: `<>`
- List: `++`
- Others: `|>`, `|`, `.`

### Modules and Functions
- `Kernel`: Basic operations and guards
- `Map`: Map manipulation
- `String`: String operations (except atom conversion)
- `Enum`: Collection operations
- `Date`, `DateTime`, `NaiveDateTime`: Date/time operations
- `List`: List operations
- `Integer`: Integer operations
- `Regex`: Regular expressions
- `URI`: URI operations
- `Base`: Encoding/decoding
- `UUID`: UUID operations
- `JSON`: JSON operations

## Security Features

MiniElixir is designed with security in mind:

- **No filesystem access**: File operations are not allowed
- **No network access**: Network operations are blocked
- **No atom creation from strings**: Prevents atom table exhaustion
- **No module definitions inside functions**: Prevents dynamic module creation
- **No assignment to function arguments**: Prevents argument mutation
- **Automatic cleanup**: Modules are deleted from VM after execution
- **Memory bounds**: Protection against large binary creation

## Error Handling

The function returns descriptive error messages for various failure cases:

```elixir
# Module name mismatch
{:error, "Module name mismatch. Expected Calculator, got Math"}

# Function not found
{:error, "Function add/2 not found"}

# Security violation
{:error, "Forbidden function: File.read"}

# Runtime error
{:error, "division by zero"}
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

This project is licensed under the MIT License.

