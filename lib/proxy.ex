defmodule Proxy do

  def header_processor( conn, headers, state ) do
    new_headers = [ { "x-rewrite-url", conn.request_path } | headers ]
    { new_headers, state }
  end

  # Forwards to the specified path.  The path is an array of URL
  # components.
  def forward( conn, path, base ) do
    new_extension = Enum.join( path, "/" )
    full_path = base <> new_extension
    processors = %{
      header_processor: fn (headers, state) ->
        headers = [ { "x-rewrite-url", conn.request_path } | headers ]
        { headers, state }
      end,
      chunk_processor: fn (chunk, state) ->
        # IO.puts "Received chunk:"
        # IO.inspect chunk
        { chunk, state }
      end,
      body_processor: fn (body, state) ->
        # IO.puts "Received body:"
        # IO.inspect body
        { body, state }
      end,
      finish_hook: fn (state) ->
        # IO.puts "Fully received body"
        # IO.puts state.body
        # IO.puts "Current state:"
        # IO.inspect state
        { true, state }
      end,
      state: %{is_processor_state: true, body: "", headers: %{}, status_code: 200, cache_keys: [], clear_keys: []}
    }

    opts = PlugProxy.init url: full_path
    conn
    |> Map.put( :processors, processors )
    |> PlugProxy.call( opts )
  end

end
