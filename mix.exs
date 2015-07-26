defmodule Dispatcher.Mixfile do
  use Mix.Project

  def project do
    [app: :dispatcher,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps,
     aliases: aliases]
  end

  def aliases do
    [server: ["run", &Dispatcher.start/1]]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :cowboy, :plug, :hackney]]
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
    [{:cowboy, "~> 1.0.2"},
     {:plug, "~> 0.12"},
     {:hackney, "~> 1.0"}]
  end
end
