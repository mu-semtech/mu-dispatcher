defmodule Proxy do
  import Plug.Conn

  # Support for dispatching the connection
  def send(conn, uri) do
    # Start a request to the client saying we will stream the body.
    # We are simply passing all req_headers forward.

    url = build_url( uri, conn.query_string )
    request_headers = forwarded_request_headers( conn )

    IO.puts "Forwarding request to #{url}"

    {:ok, client} = :hackney.request(conn.method, url, request_headers, :stream, [recv_timeout: 1500000000])

    conn
    |> write_proxy(client)
    |> read_proxy(client)
  end

  defp build_url( uri, "" ), do: uri
  defp build_url( uri, query_string ), do: uri <> "?" <> query_string

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
		headers = Enum.map(headers, fn {k,v} -> {String.downcase(k),v} end)

    %{conn | resp_headers: headers}
    |> send_resp(status, body)
  end

  # Returns all request headers which should be forwarded for the
  # given connection.  This may add new request headers.
  defp forwarded_request_headers( conn ) do
    cleaned_headers = List.keydelete( conn.req_headers, "Transfer-Encoding", 1 )
    [ { "X-Rewrite-Url", conn.request_path } | cleaned_headers ]
  end

  # Forwards to the specified path.  The path is an array of URL
  # components.
  def forward( conn, path, base ) do
    new_extension = Enum.join( path, "/" )
    full_path = base <> new_extension
    Proxy.send conn, full_path
  end

end
