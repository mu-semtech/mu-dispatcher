defmodule Dispatcher do
  use Matcher

  define_accept_types [
    text: [ "text/*" ],
    html: [ "text/html", "application/xhtml+html" ],
    json: [ "application/json", "application/vnd.api+json" ]
  ]

  # get "/*_rest", %{ accept: %{ html: true } } do
  #   Proxy.forward conn, [], "http://static/ember-app/index.html"
  # end

  # get "/assets/*rest", %{} do
  #   Proxy.forward conn, rest, "http://static/assets/"
  # end

  post "/hello/erika", %{} do
    Plug.Conn.send_resp conn, 401, "FORBIDDEN"
  end

  # 200 microservice dispatching

  match "/hello/erika", %{ accept: %{ json: true } } do
    Plug.Conn.send_resp conn, 200, "{ \"message\": \"Hello Erika\" }"
  end

  match "/hello/erika", %{ accept: %{ html: true } } do
    Plug.Conn.send_resp conn, 200, "<html><head><title>Hello</title></head><body>Hello Erika</body></html>"
  end

  # 404 routes

  match "/hello/aad/*_rest", %{ accept: %{ json: true } } do
    Plug.Conn.send_resp conn, 200, "{ \"message\": \"Hello Aad\" }"
  end

  match "/*_rest", %{ accept: %{ json: true }, last_call: true } do
    Plug.Conn.send_resp conn, 404, "{ \"errors\": [ \"message\": \"Not found\", \"status\": 404 } ] }"
  end

  match "/*_rest", %{ accept: %{ html: true }, last_call: true } do
    Plug.Conn.send_resp conn, 404, "<html><head><title>Not found</title></head><body>No acceptable response found</body></html>"
  end

  match "/*_rest", %{ last_call: true } do
    Plug.Conn.send_resp conn, 404, "No response found"
  end

end
