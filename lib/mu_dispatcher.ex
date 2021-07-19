defmodule MuDispatcher do
  @moduledoc """
  MuDispatcher forwards messages to desired microservices
  """

  use Application
  require Logger

  def start(_argv, _args) do
    port = 80

    children = [
      # this is kinda strange, but the 'plug:' field is not used when 'dispatch:' is provided (my understanding)
      {Plug.Adapters.Cowboy,
       scheme: :http, plug: PlugRouterDispatcher, options: [dispatch: dispatch, port: port]}
    ]

    Logger.info("Mu Dispatcher starting on port #{port}")

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/ws/[...]", WebsocketHandler, %{}},
         {:_, Plug.Cowboy.Handler, {PlugRouterDispatcher, []}}
       ]}
    ]
  end
end
