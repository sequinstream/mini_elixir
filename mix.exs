defmodule MiniElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :mini_elixir,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A safe sandbox for evaluating Elixir code with restricted functionality",
      package: package(),
      docs: [
        main: "MiniElixir",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end

  defp package do
    [
      name: "mini_elixir",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/sequinstream/mini_elixir"
      }
    ]
  end
end
