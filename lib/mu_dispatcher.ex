defmodule MuDispatcher do
  @moduledoc """
  MuDispatcher forwards messages to desired microservices
  """

  use Application
  require Logger

  def start(_argv, _args) do
    port = 80

    children = [
      {Plug.Cowboy, scheme: :http, plug: PlugRouterDispatcher, options: [port: port]}
    ]

    Logger.info("Mu Dispatcher starting on port #{port}")

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
