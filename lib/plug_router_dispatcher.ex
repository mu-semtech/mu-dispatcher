defmodule PlugRouterDispatcher do
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  match _ do
    Dispatcher.dispatch( conn )
  end
end
