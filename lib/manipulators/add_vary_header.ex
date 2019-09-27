defmodule Manipulators.AddVaryHeader do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    headers =
      if Enum.find(headers, &match?({"vary", _}, &1)) do
        headers
      else
        [{"vary", "accept, cookie"} | headers]
      end

    {headers, connection}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
