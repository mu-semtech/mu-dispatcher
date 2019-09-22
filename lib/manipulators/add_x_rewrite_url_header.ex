defmodule Manipulators.AddXRewriteUrlHeader do
  @behaviour ProxyManipulator

  @impl true
  def headers( headers, {frontend_conn, _backend_conn} = connection ) do
    new_headers = [{"x-rewrite-url", frontend_conn.request_path} | headers]
    {new_headers, connection}
  end

  @impl true
  def chunk(_,_), do: :skip

  @impl true
  def finish(_,_), do: :skip
end
