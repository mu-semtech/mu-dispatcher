defmodule Dispatcher.Mixfile do
  use Mix.Project

  def project do
    [app: :dispatcher, version: "2.0.0", elixir: "~> 1.7", deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      extra_applications: [:logger, :plug_mint_proxy, :cowboy, :plug],
      mod: {MuDispatcher, []},
      env: [],
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
      {:cowboy_ws_proxy, git: "https://github.com/ajuvercr/elixir-cowboy-ws-proxy-handler.git", tag: "v0.1"},
      {:plug_mint_proxy,
       git: "https://github.com/madnificent/plug-mint-proxy.git", tag: "v0.0.2"},
      # {:plug, "~> 1.10.4"},
      {:plug_cowboy, "~> 2.4.0"},
      {:gun, "~> 2.0.0-rc.2"},
      {:accept, "~> 0.3.5"},
      {:observer_cli, "~> 1.5"},
      {:exsync, "~> 0.2", only: :dev}
    ]
  end
end
