defmodule Manipulators.RemoveAcceptEncodingHeader do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    # headers =
    #   headers
    #   |> Enum.reject( &match?( {"accept_encoding", _}, &1 ) )
    {headers, connection}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true

  def finish(_, _), do: :skip
end
