defmodule Manifold.Mixfile do
  use Mix.Project

  def project do
    [
      app: :manifold,
      version: "1.4.0",
      elixir: "~> 1.5",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),
      # https://github.com/whitfin/local-cluster#setup
      aliases: [
        test: "test --no-start"
      ]
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
      {:benchfella, "~> 0.3.0", only: :test},
      {:local_cluster, "~> 1.2", only: [:test]}
    ]
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
