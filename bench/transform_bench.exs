alias MiniElixir

input = %{
  "first" => "john",
  "last" => "doe",
  "tags" => ["z", "a", "m"],
  "meta" => %{"age" => 30, "active" => true}
}

code_persistent = ~S"""
defmodule TransformPersistent do
  def transform(record) do
    %{
      name: String.capitalize(record["first"]) <> " " <> String.capitalize(record["last"]),
      tags: record["tags"] |> Enum.map(&String.upcase/1) |> Enum.sort(),
      meta: Map.put(record["meta"], "year", 1990)
    }
  end
end
"""

code_ephemeral = ~S"""
defmodule TransformEphemeral do
  def transform(record) do
    %{
      name: String.capitalize(record["first"]) <> " " <> String.capitalize(record["last"]),
      tags: record["tags"] |> Enum.map(&String.upcase/1) |> Enum.sort(),
      meta: Map.put(record["meta"], "year", 1990)
    }
  end
end
"""

native_fun = fn rec ->
  %{
    name: String.capitalize(rec["first"]) <> " " <> String.capitalize(rec["last"]),
    tags: rec["tags"] |> Enum.map(&String.upcase/1) |> Enum.sort(),
    meta: Map.put(rec["meta"], "year", 1990)
  }
end

# preload persistent module once for the hot path
{:ok, _} = MiniElixir.eval(code_persistent, TransformPersistent, :transform, [input], persistent: true)

Benchee.run(%{
  "Native" => fn -> native_fun.(input) end,
  "MiniElixir.eval/5 persistent: true (hot call)" => fn ->
    {:ok, _res} = MiniElixir.eval(code_persistent, TransformPersistent, :transform, [input], persistent: true)
  end,
  "MiniElixir.eval/5 persistent: false" => fn ->
    {:ok, _res} = MiniElixir.eval(code_ephemeral, TransformEphemeral, :transform, [input], persistent: false)
  end
})
