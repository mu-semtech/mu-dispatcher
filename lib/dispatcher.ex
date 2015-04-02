defmodule Dispatcher do
  use Plug.Router

  def start(_argv) do
    port = 4000
    Plug.Adapters.Cowboy.http __MODULE__, [], port: port
  end

  plug :match
  plug :dispatch

  get "/hello" do
    send_resp( conn, 200, "world" )
  end

  get "/" do
    send_resp( conn, 200, "This is plug" )
  end

  get "/lisply/*path" do
    new_extension = Enum.join( path, "/" )
    full_path = "http://localhost:8080/" <> new_extension
    Proxy.send conn, full_path
  end

  match _ do
    send_resp( conn, 404, "Route not found" )
  end

end
