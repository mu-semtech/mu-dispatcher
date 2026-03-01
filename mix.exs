defmodule Dispatcher.Mixfile do
  use Mix.Project

  def project do
    [app: :dispatcher, version: "2.1.1", elixir: "~> 1.7", deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      extra_applications: [:logger, :plug_mint_proxy, :cowboy, :plug, :accept],
      mod: {MuDispatcher, []},
      env: []
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:plug_mint_proxy, git: "https://github.com/madnificent/plug-mint-proxy.git", tag: "v0.0.2"},
      {:accept, "~> 0.3.5"},
      {:observer_cli, "~> 1.5"}
    ]
  end
end
