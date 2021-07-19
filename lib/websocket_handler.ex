alias Dispatcher.Log

defmodule WebsocketHandler do
  @behaviour :cowboy_websocket

  def init(req, state) do
    # Get path info
    {_, target} =
      :cowboy_req.parse_qs(req)
      |> Enum.find(fn {head, _} -> head == "target" end)

    ws =
      Dispatcher.get_websocket(target)
      |> Log.inspect(:ws_log_all, label: "websocket connecting to target")

    new_state =
      state
      |> Map.put(:host, ws.host)
      |> Map.put(:path, ws.path)
      |> Map.put(:port, ws.port)
      |> Map.put(:ready, false)
      |> Map.put(:buffer, [])

    {:cowboy_websocket, req, new_state}
  end

  def websocket_init(state) do
    Log.inspect(state, :log_ws_all, label: "websocket all start connect with")

    connect_opts = %{
      connect_timeout: :timer.minutes(1),
      retry: 10,
      retry_timeout: 300
    }

    # conn :: pid()
    {:ok, conn} = :gun.open(to_charlist(state.host), state.port, connect_opts)
    {:ok, :http} = :gun.await_up(conn)

    # streamref :: StreamRef
    streamref = :gun.ws_upgrade(conn, to_charlist(state.path))

    new_state =
      state
      |> Map.put(:back_pid, conn)
      |> Map.put(:back_ref, streamref)

    {:ok, new_state}
  end

  def websocket_handle(message, state) do
    new_state =
      if state.ready do
        Log.inspect(message, :log_ws_frontend, label: "websocket frontend message")
        |> Log.inspect(:log_ws_all, label: "websocket all frontend message")

        :ok = :gun.ws_send(state.back_pid, state.back_ref, message)
        state
      else
        Log.inspect(message, :log_ws_frontend,
          label: "websocket frontend message postponed (connection not started)"
        )
        |> Log.inspect(:log_ws_all,
          label: "websocket all frontend message postponed (connection not started)"
        )

        buf = [message | state.buffer]
        Map.put(state, :buffer, buf)
      end

    {:ok, new_state}
  end

  def websocket_info({:gun_ws, _pid, _ref, msg}, state) do
    Log.inspect(msg, :log_ws_backend, label: "websocket backend message")
    |> Log.inspect(:log_ws_all, label: "websocket all backend message")

    {:reply, msg, state}
  end

  def websocket_info({:gun_error, _gun_pid, _stream_ref, reason}, _state) do
    exit({:ws_upgrade_failed, reason})
  end

  def websocket_info({:gun_response, _gun_pid, _, _, status, headers}, _state) do
    Log.inspect({"Websocket upgrade failed.", headers}, :log_ws_all, label: "websocket all")
    exit({:ws_upgrade_failed, status, headers})
  end

  def websocket_info({:gun_upgrade, _, _, ["websocket"], headers}, state) do
    Log.inspect("ws upgrade succesful", :log_ws_all, label: "websocket all")
    Log.inspect(headers, :log_ws_all, label: "websocket all")

    state.buffer
    |> Enum.reverse()
    |> Enum.each(fn x ->
      Log.inspect(x, :log_ws_frontend, label: "postponed sending message")
      Log.inspect(x, :log_ws_all, label: "postponed sending message")
      :gun.ws_send(state.back_pid, state.back_ref, x)
    end)

    new_state =
      state
      |> Map.put(:ready, true)
      |> Map.put(:buffer, [])

    {:ok, new_state}
  end

  def websocket_info(info, state) do
    Log.inspect(info, :log_ws_unhandled, label: "websocket unhandled info")
    |> Log.inspect(:log_ws_all, label: "websocket all info")

    {:ok, state}
  end

  def terminate(_reason, _req, state) do
    Log.inspect("Closing", :log_ws_all, label: "websocket all")
    :gun.shutdown(state.back_pid)
    :ok
  end
end
