defmodule Dispatcher do

  def init( options ) do
    options
  end

  def call(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp( 200, "Hello World" )
  end
end
