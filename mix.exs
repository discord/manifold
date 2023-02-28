defmodule Manifold.Mixfile do
  use Mix.Project

  def project do
    [
      app: :manifold,
      version: "1.5.1",
      elixir: "~> 1.5",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      applications: [:logger],
      mod: {Manifold, []},
    ]
  end

  defp deps do
    [
      {:benchfella, "~> 0.3.0", only: [:dev, :test], runtime: false},
    ]
  end

  defp elixirc_paths(:test) do
    elixirc_paths(:any) ++ ["test/support"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end

  def package do
    [
      name: :manifold,
      description: "Fast batch message passing between nodes for Erlang/Elixir.",
      maintainers: [],
      licenses: ["MIT"],
      files: ["lib/*", "mix.exs", "README*", "LICENSE*"],
      links: %{
        "GitHub" => "https://github.com/discordapp/manifold",
      },
    ]
  end
end
