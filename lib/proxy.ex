defmodule Proxy do
  @request_manipulators [Manipulators.AddXRewriteUrlHeader,Manipulators.RemoveAcceptEncodingHeader]
  @response_manipulators []
  @manipulators ProxyManipulatorSettings.make_settings(
                  @request_manipulators,
                  @response_manipulators
                )

  # Forwards to the specified path.  The path is an array of URL
  # components.
  def forward(conn, path, base) do
    ConnectionForwarder.forward(
      conn,
      path,
      base,
      @manipulators)
  end
end
