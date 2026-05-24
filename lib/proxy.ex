defmodule Proxy do
  require Logger
  @request_manipulators [Manipulators.AddXRewriteUrlHeader,Manipulators.RemoveAcceptEncodingHeader]
  @response_manipulators [Manipulators.AddVaryHeader]
  @manipulators ProxyManipulatorSettings.make_settings(
                  @request_manipulators,
                  @response_manipulators
                )

  def dispatchInfo(conn, base) do
    {_header, accept} = Enum.find(conn.req_headers, fn {name, _val} -> ^name = "accept" end)
    "Dispatching #{conn.method} #{conn.request_path} to #{base} (accept: #{accept})"
  end

  # Forwards to the specified path.  The path is an array of URL
  # components.
  def forward(conn, path, base) do
    Logger.info(fn -> dispatchInfo(conn, base) end)
    ConnectionForwarder.forward(
      conn,
      path,
      base,
      @manipulators)
  end
end
