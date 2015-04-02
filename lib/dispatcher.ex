defmodule Dispatcher do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/hello" do
    send_resp( conn, 200, "world" )
  end

  get "/" do
    send_resp( conn, 200, "This is plug" )
  end

  match _ do
    send_resp( conn, 404, "Route not found" )
  end

end
