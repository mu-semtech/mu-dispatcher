defmodule PlugRouterDispatcher do
  use Plug.Router

  def start(_argv) do
    port = 80
    IO.puts("Starting Plug with Cowboy on port #{port}")
    Plug.Adapters.Cowboy.http(__MODULE__, [], port: port)
    :timer.sleep(:infinity)
  end

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  match _ do
    Dispatcher.dispatch( conn )
  end
end
