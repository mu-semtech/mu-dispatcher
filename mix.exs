defmodule Dispatcher.Mixfile do
  use Mix.Project

  def project do
    [app: :dispatcher,
     version: "1.1.2",
     elixir: "~> 1.0",
     deps: deps(),
     aliases: aliases()]
  end

  def aliases do
    [server: ["run", &PlugRouterDispatcher.start/1]]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :cowboy, :plug, :hackney, :accept]]
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
    [{:plug_proxy, git: "https://github.com/madnificent/plug-proxy.git"},
     {:accept, "~> 0.3.5"}]
  end
end
