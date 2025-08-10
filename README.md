# MiniElixir

MiniElixir provides a safe sandbox for evaluating Elixir code with restricted functionality. It allows users to write and execute Elixir code in a controlled environment where only whitelisted functions and operators are available.

## Benchmarks

Run:

```bash
mix run bench/transform_bench.exs
```

Example results:

```
Name                                                    ips        average  deviation         median         99th %
Native                                               1.14 M      876.13 ns  ±2452.00%         750 ns        1083 ns
MiniElixir.eval/5 persistent: true (hot call)        1.02 M      979.19 ns  ±1911.87%         833 ns        1666 ns
MiniElixir.eval/5 persistent: false               0.00016 M  6153605.28 ns     ±5.47%     6123417 ns  6954676.86 ns

Comparison:
Native                                               1.14 M
MiniElixir.eval/5 persistent: true (hot call)        1.02 M - 1.12x slower +103.06 ns
MiniElixir.eval/5 persistent: false               0.00016 M - 7023.61x slower +6152729.14 ns
```

## Status & Security

> ⚠️ **Alpha Status**: This library is not ready for production. APIs and validation rules may change. Use at your own risk.

If you encounter any security issues or potential vulnerabilities, **please create an issue** in the GitHub repository:

- Issues: [github.com/sequinstream/mini_elixir/issues](https://github.com/sequinstream/mini_elixir/issues)

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

### `MiniElixir.eval/5`

Evaluates a string of Elixir code in a safe sandbox environment.

```elixir
MiniElixir.eval(code, module, function, args, opts \\ [persistent: true]) :: {:ok, result} | {:error, reason}
```

#### Parameters

- `code` (string): Elixir code string containing a module definition
- `module` (atom): The module name to define the function in
- `function` (atom): The name of the function to define and call
- `args` (list): List of arguments to pass to the function
- `opts` (keyword): Options
  - `:persistent` (boolean, default: `true`): when true, the module is kept loaded and reused on subsequent calls; when false, the module is purged/deleted after the call

#### Returns

- `{:ok, result}` on success
- `{:error, reason}` on failure

## Allowed vs Disallowed

MiniElixir validates code before it is compiled/executed. Only a specific set of operators and modules are allowed. Anything not listed is rejected during validation.

### Allowed operators
- Arithmetic: `+`, `-`, `*`, `/`
- Comparison: `==`, `!=`, `===`, `!==`, `>`, `>=`, `<`, `<=`
- Logical: `&&`, `||`, `and`, `or`, `not`
- String concatenation: `<>`
- List concatenation: `++`
- Pipe: `|>`
- List cons and map update: `|` (e.g., `[h | t]`, `%{map | key: v}`)
- Access/tuple/bitstring/guards: `.`, `{}`, `<<>>`, `::`, `when`, `->`, `fn`, `__block__`

### Allowed modules and calls
- Kernel:
  - Guards: selected guards (e.g., `is_integer/1`, `is_binary/1`, ...)
  - Functions: selected functions (e.g., `abs/1`, `to_string/1`, ...)
- Kernel sigils: `~C ~D ~N ~R ~S ~T ~U ~c ~r ~s ~w`
- Access: `Access.get/2`
- Map: all functions
- String: all except `String.to_atom/1` and `String.to_existing_atom/1`
- Enum: all functions
- Date, DateTime, NaiveDateTime: all functions
- Decimal: all functions
- URI, Base, UUID, JSON, Integer, Regex, Eden, List: all functions
- Local function calls: calling a function by name (e.g., recursion) is allowed
- Calling through function arguments: allowed (e.g., `record[:id]`, `changes["foo"]`)

### Disallowed (examples; anything not in the allowed list is blocked)
- Filesystem: `File.read!/1`, `File.write/2`, etc.
- I/O and OS: `IO.puts/1`, `System.cmd/2`, `:os.cmd/1`, `Port`, `:erlang` internals
- Code loading/eval: `Code.eval_string/1`, dynamic module creation inside the function
- Network/process: `:rpc`, `GenServer`, `Task`, `Process`, `Application`
- Atom creation from strings: `String.to_atom/1`, `String.to_existing_atom/1`
- Defining modules or functions inside the validated body: `defmodule`, `def`, `defp`

Why a call is blocked: the validator resolves the call path (e.g., `File.read!(path)` → `File.read!`) and rejects it if the module/function isn’t on the allowlist, returning an error like `Forbidden function: File.read!`.

## Contributing

Contributions are more than welcome. Useful areas include:

- **Testing**: Add unit tests and edge cases; consider property-based tests (e.g., `stream_data`) or fuzzing for the validator and transformer.
- **Performance**: Profile and optimize hot paths; extend `bench/transform_bench.exs`; include before/after numbers in PRs where relevant.
- **Security**: Review the allowlist, harden validation, add negative tests, and propose threat-model updates. For suspected vulnerabilities, open an issue rather than sharing public PoCs.
- **Documentation**: Improve the README and API docs; add short guides.
- **Examples**: Provide practical code samples and usage recipes.

### How to contribute

1. Fork the repository and create a feature branch.
2. Run tests locally: `mix test`.
3. Open a PR with a concise description and, if applicable, benchmarks or security rationale.

Questions or proposals:

- Issues: [github.com/sequinstream/mini_elixir/issues](https://github.com/sequinstream/mini_elixir/issues)
