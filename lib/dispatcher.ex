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
    proxy conn, full_path
  end

  match _ do
    send_resp( conn, 404, "Route not found" )
  end

  # Support for dispatching the connection
  def proxy(conn, uri) do
    # Start a request to the client saying we will stream the body.
    # We are simply passing all req_headers forward.

    {:ok, client} = :hackney.request(:get, uri, conn.req_headers, :stream, [])

    conn
    |> write_proxy(client)
    |> read_proxy(client)
  end

  # Reads the connection body and write it to the
  # client recursively.
  defp write_proxy(conn, client) do
    # Check Plug.Conn.read_body/2 docs for maximum body value,
    # the size of each chunk, and supported timeout values.
    case read_body(conn, []) do
      {:ok, body, conn} ->
        :hackney.send_body(client, body)
        conn
      {:more, body, conn} ->
        :hackney.send_body(client, body)
        write_proxy(conn, client)
    end
  end

  # Reads the client response and sends it back.
  defp read_proxy(conn, client) do
    {:ok, status, headers, client} = :hackney.start_response(client)
    {:ok, body} = :hackney.body(client)

    # Delete the transfer encoding header. Ideally, we would read
    # if it is chunked or not and act accordingly to support streaming.
    #
    # We may also need to delete other headers in a proxy.
    headers = List.keydelete(headers, "Transfer-Encoding", 1)

    %{conn | resp_headers: headers}
    |> send_resp(status, body)
  end

end
