defmodule Manifold.Mixfile do
  use Mix.Project

  def project do
    [
      app: :manifold,
      version: "1.2.0",
      elixir: "~> 1.5",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package()
    ]
  end

  def application do
    [
      applications: [:logger],
      mod: {Manifold, []},
    ]
  end

  defp deps do
    []
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
