defmodule MuDispatcher do
  @moduledoc """
  MuDispatcher forwards messages to desired microservices
  """

  use Application
  require Logger

  def start(_argv, _args) do
    port = 80

    children = [
      {
        Plug.Cowboy,
        scheme: :http,
        plug: PlugRouterDispatcher,
        options: [
          port: port,
          protocol_options: [
            idle_timeout: Application.get_env(:mu_identifier, :idle_timeout),
            max_request_line_length: Application.get_env(:mu_identifier, :max_url_length)
          ]
        ]}
    ]

    Logger.info("Mu Dispatcher starting on port #{port}")

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
