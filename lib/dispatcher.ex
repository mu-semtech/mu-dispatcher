defmodule Dispatcher do
  use Plug.Router

  def start(_argv) do
    port = 4000
    Plug.Adapters.Cowboy.http __MODULE__, [], port: port
    :timer.sleep(:infinity)
  end

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/hello" do
    send_resp( conn, 200, "world" )
  end

  get "/" do
    send_resp( conn, 200, "This is plug" )
  end

  match "/lisply/*path" do
    # Proxy.forward conn, path, "http://localhost:8080/"
    Proxy.forward conn, path, "http://172.17.42.1:8080/"
  end

  match _ do
    send_resp( conn, 404, "Route not found" )
  end

end
