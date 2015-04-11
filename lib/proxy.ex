defmodule Proxy do
  import Plug.Conn

  # Support for dispatching the connection
  def send(conn, uri) do
    # Start a request to the client saying we will stream the body.
    # We are simply passing all req_headers forward.

    {:ok, client} = :hackney.request(conn.method, uri, conn.req_headers, :stream, [])

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

  # Forwards to the specified path.  The path is an array of URL
  # components.
  def forward( conn, path, base ) do
    new_extension = Enum.join( path, "/" )
    full_path = base <> new_extension
    Proxy.send conn, full_path
  end

end
