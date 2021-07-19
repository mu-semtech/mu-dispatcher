defmodule Dispatcher do
  use Matcher

  define_accept_types(
    text: ["text/*"],
    html: ["text/html", "application/xhtml+html"],
    json: ["application/json", "application/vnd.api+json"]
  )

  # get "/*_rest", %{ accept: %{ html: true } } do
  #   Proxy.forward conn, [], "http://static/ember-app/index.html"
  # end

  # get "/assets/*rest", %{} do
  #   Proxy.forward conn, rest, "http://static/assets/"
  # end

  post "/hello/erika", %{} do
    Plug.Conn.send_resp(conn, 401, "FORBIDDEN")
  end

  # 200 microservice dispatching

  match "/hello/erika", %{accept: %{json: true}} do
    Plug.Conn.send_resp(conn, 200, "{ \"message\": \"Hello Erika\" }\n")
  end

  match "/hello/erika", %{accept: %{html: true}} do
    Plug.Conn.send_resp(
      conn,
      200,
      "<html><head><title>Hello</title></head><body>Hello Erika</body></html>"
    )
  end

  # 404 routes

  match "/hello/aad/*_rest", %{accept: %{json: true}} do
    Plug.Conn.send_resp(conn, 200, "{ \"message\": \"Hello Aad\" }")
  end

  # Websocket example route
  # This forwards to /ws?target=<...>
  # Then forwards websocket from /ws?target=<...> to ws://localhost:7999

  match "/ws2" do
    ws(conn, "ws://localhost:7999")
  end


  match "__", %{last_call: true} do
    send_resp(conn, 404, "Route not found.  See config/dispatcher.ex")
  end
end
