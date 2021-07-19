alias Dispatcher.Log

defmodule Matcher do
  defmacro __using__(_opts) do
    # Set this attribute _BEFORE_ any code is ran
    Module.register_attribute(__CALLER__.module, :websocket, accumulate: true)

    quote do
      require Matcher
      import Matcher
      import Plug.Router, only: [forward: 2]
      import Plug.Conn, only: [send_resp: 3]
      import Proxy, only: [forward: 3]

      def layers do
        [:service, :last_call]
      end

      defoverridable layers: 0

      def dispatch(conn) do
        Matcher.dispatch_call(
          conn,
          fn -> accept_types() end,
          fn -> layers() end,
          fn a, b, c, d -> do_match(a, b, c, d) end
        )
      end

      @matchers []

      @before_compile Matcher
    end
  end

  defmacro ws(conn, host) do
    # host = "ws://localhost:8000/test"

    parsed =
      URI.parse(host)
      |> Log.inspect(:log_ws_all, label: "Creating websocket route")

    id = for _ <- 1..24, into: "", do: <<Enum.random('0123456789abcdef')>>

    host = parsed.host || "localhost"
    port = parsed.port || 80
    path = parsed.path || "/"

    Module.put_attribute(__CALLER__.module, :websocket, %{
      host: host,
      port: port,
      path: path,
      id: id
    })

    # Return redirect things
    quote do
      unquote(conn)
      |> Plug.Conn.resp(:found, "")
      |> Plug.Conn.put_resp_header("location", "/ws?target=" <> unquote(id))
    end
  end

  defmacro get(path, options \\ quote(do: %{}), do: block) do
    quote do
      match_method(get, unquote(path), unquote(options), do: unquote(block))
    end
  end

  defmacro put(path, options \\ quote(do: %{}), do: block) do
    quote do
      match_method(put, unquote(path), unquote(options), do: unquote(block))
    end
  end

  defmacro post(path, options \\ quote(do: %{}), do: block) do
    quote do
      match_method(post, unquote(path), unquote(options), do: unquote(block))
    end
  end

  defmacro delete(path, options \\ quote(do: %{}), do: block) do
    quote do
      match_method(delete, unquote(path), unquote(options), do: unquote(block))
    end
  end

  defmacro patch(path, options \\ quote(do: %{}), do: block) do
    quote do
      match_method(patch, unquote(path), unquote(options), do: unquote(block))
    end
  end

  defmacro head(path, options \\ quote(do: %{}), do: block) do
    quote do
      match_method(head, unquote(path), unquote(options), do: unquote(block))
    end
  end

  defmacro options(path, options \\ quote(do: %{}), do: block) do
    quote do
      match_method(options, unquote(path), unquote(options), do: unquote(block))
    end
  end

  defmacro match(path, options \\ quote(do: %{}), do: block) do
    quote do
      match_method(any, unquote(path), unquote(options), do: unquote(block))
    end
  end

  defmacro last_match do
    message =
      "The last_match statement is no longer needed, may remove it from your dispatcher.ex"

    quote do
      IO.puts(unquote(message))
    end
  end

  defmacro match_method(call, path, options, do: block) do
    quote do
      @matchers [
        {unquote(Macro.escape(call)), unquote(Macro.escape(path)), unquote(Macro.escape(options)),
         unquote(Macro.escape(block))}
        | @matchers
      ]
    end
  end

  defmacro __before_compile__(_env) do
    matchers =
      Module.get_attribute(__CALLER__.module, :matchers)
      |> Enum.map(fn {call, path, options, block} ->
        make_match_method(call, path, options, block, __CALLER__)
      end)

    last_match_def =
      quote do
        def do_match(_, _, _, _) do
          {:skip}
        end
      end

    socket_dict_f =
      quote do
        def websockets() do
          Enum.reduce(@websocket, %{}, fn x, acc -> Map.put(acc, x.id, x) end)
        end

        def get_websocket(id) do
          Enum.find(@websocket, fn x -> x.id == id end)
        end
      end

    [socket_dict_f, last_match_def | matchers]
    |> Enum.reverse()
  end

  defp extract_value(key, caller) do
    case key do
      {:@, _, [{name, _, _}]} ->
        Module.get_attribute(caller.module, name)
        |> Macro.escape()

      _ ->
        key
    end
  end

  defp rework_options_for_host(options) do
    case options do
      {:%{}, any, list} ->
        if List.keymember?(list, :host, 0) do
          {_key, value} = List.keyfind(list, :host, 0)

          if is_binary(value) do
            # Okay, so the host key is a string.  We should cut it
            # into pieces to make it look like an array.
            new_host =
              case String.split(value, ".") do
                ["*", thing | rest] ->
                  Enum.reverse([{:|, [], [thing, {:_, [], Elixir}]} | rest])

                ["*"] ->
                  quote do
                    [_]
                  end

                things ->
                  Enum.reverse(things)
              end

            new_list = [{:host, new_host} | List.keydelete(list, :host, 0)]

            {:%{}, any, new_list}
          else
            options
          end
        else
          options
        end

      _ ->
        options
    end
  end

  defp rework_options_for_array_accept(options) do
    case options do
      {:%{}, any, list} ->
        if List.keymember?(list, :accept, 0) do
          {_key, value} = List.keyfind(list, :accept, 0)

          new_accept =
            case value do
              # convert item
              [item] ->
                {:%{}, [], [{item, true}]}

              [_item | _rest] ->
                raise "Multiple items in accept arrays are not supported."

              {:%{}, _, _} ->
                value
            end

          new_list =
            list
            |> Keyword.drop([:accept])
            |> Keyword.merge(accept: new_accept)

          {:%{}, any, new_list}
        else
          options
        end

      _ ->
        options
    end
  end

  # Builds a method in the form of:
  #
  # def do_match( "GET", "/hello/erika/", %{ accept: %{} }, conn ) do
  #    ...
  # end
  def make_match_method(call, path, options, block, caller) do
    path = extract_value(path, caller)

    options =
      options
      |> extract_value(caller)
      |> rework_options_for_host()
      |> rework_options_for_array_accept()

    # Throw warning when strange conditions occur
    unless String.starts_with?(path, "/") do
      IO.puts("WARNING: invalid path: #{path} does not start with a `/`")
    end

    # Implementation
    call_name =
      call
      |> elem(0)
      |> Atom.to_string()
      |> String.upcase()
      |> (fn
            "ANY" -> Macro.var(:_, nil)
            "_" -> Macro.var(:_, nil)
            str -> str
          end).()

    # Creates the variable(s) for the parsed path
    process_derived_path_elements = fn elements ->
      reversed_elements = Enum.reverse(elements)

      case reversed_elements do
        [{:rest, rest_var}, {_name, second_item} | rest] ->
          first =
            quote do
              [unquote(second_item) | unquote(rest_var)]
            end

          rest =
            Enum.map(rest, fn {_type, element} ->
              element
            end)

          (first ++ rest)
          |> Enum.reverse()

        [{:rest, rest_var}] ->
          rest_var

        _ ->
          Enum.map(reversed_elements, fn {_type, element} ->
            element
          end)
          |> Enum.reverse()
      end
    end

    path_array_args =
      path
      |> String.split("/")
      |> (fn [_ | rest] -> rest end).()
      |> Enum.map(fn element ->
        case element do
          <<":"::utf8, name::binary>> ->
            {:var, Macro.var(String.to_atom(name), nil)}

          <<"*"::utf8, name::binary>> ->
            {:rest, Macro.var(String.to_atom(name), nil)}

          _ ->
            {:fixed, element}
        end
      end)
      |> process_derived_path_elements.()

    conn_var = Macro.var(:conn, nil)

    quote do
      def do_match(
            unquote(call_name),
            unquote(path_array_args),
            unquote(options),
            unquote(conn_var)
          ) do
        unquote(block)
      end
    end
  end

  # Defines a mapping from verbal accept types to specific accept
  # types
  defmacro define_accept_types(received_accept_types) do
    quote do
      def accept_types do
        unquote(received_accept_types)
      end
    end
  end

  # Defines the layers through which the dispatcher should process
  defmacro define_layers(layers) do
    quote do
      def layers do
        unquote(layers)
      end
    end
  end

  # Call dispatching
  def dispatch_call(conn, accept_types, layers_fn, call_handler) do
    # Extract core info
    {method, path, accept_header, host} = extract_core_info_from_conn(conn)

    # Extract core request info
    accept_hashes =
      sort_and_group_accept_headers(accept_header)
      |> transform_grouped_accept_headers(accept_types)

    # |> IO.inspect(label: "accept hashes")

    # layers |> IO.inspect(label: "layers" )
    # Try to find a solution in each of the layers
    layers =
      layers_fn.()
      |> Log.inspect(:log_available_layers, "Available layers")

    reverse_host = Enum.reverse(host)

    response_conn =
      layers
      |> Enum.find_value(fn layer ->
        Log.log(:log_layer_start_processing, "Starting to process layer #{layer}")

        # For each set of media types, go over the defined calls searching
        # for a handled response.
        layer_response =
          accept_hashes
          |> Enum.find_value(fn accept ->
            options =
              %{accept: accept, host: host, reverse_host: reverse_host, layer: layer}
              # Also use old format of layer_name: true
              |> Map.put(layer, true)

            case call_handler.(method, path, options, conn) do
              {:skip} -> nil
              conn -> conn
            end
          end)

        Log.log(
          :log_layer_matching,
          "Layer #{layer} gave response? #{(layer_response && "yes") || "no"}"
        )

        layer_response
      end)

    Log.log(:log_layer_matching, "Found response in layers? #{(response_conn && "yes") || "no"}")

    response_conn
  end

  @spec extract_core_info_from_conn(Plug.Conn) ::
          {String.t(), [String.t()], String.t(), [String.t()]}
  defp extract_core_info_from_conn(conn) do
    %{method: method, path_info: path} = conn

    accept_header =
      case Plug.Conn.get_req_header(conn, "accept") do
        [accept_header | _] -> accept_header
        _ -> ""
      end

    hostarr =
      conn.host
      |> String.split(".")
      |> Enum.reverse()

    {method, path, accept_header, hostarr}
  end

  defp transform_grouped_accept_headers(grouped_accept_headers, accept_types) do
    configured_accept_types = accept_types.()

    # Pass each accept header through each transformer
    #
    # Transformer kan be short_key: [ array_of_matching_accept_types ]
    # or a function as fn ( accept_hash_to_update, { type, subtype },
    # media_range_tuple )
    grouped_accept_headers
    # |> IO.inspect(label: "grouped accept headers")
    |> Enum.map(fn {_score, header_array} ->
      # IO.inspect(header_array, label: "processing header array")

      Enum.reduce(header_array, %{}, fn media_range_tuple, acc ->
        {_media_range, received_type, received_subtype, _score, _options} = media_range_tuple
        # |> IO.inspect( label: "Received media range tuple" )

        Enum.reduce(configured_accept_types, acc, fn
          {new_key, specified_accept_values}, acc ->
            Enum.reduce(specified_accept_values, acc, fn specified_accept_value, acc ->
              [specified_type, specified_subtype] =
                specified_accept_value
                |> String.split("/")
                |> Enum.map(&String.to_charlist/1)

              specified_tuple = {specified_type, specified_subtype}
              # |> IO.inspect( label: "Comparing specified tuple" )
              # IO.inspect( {received_type, received_subtype} , label: "with received tuple" )

              case specified_tuple do
                {^received_type, ^received_subtype} -> Map.put(acc, new_key, true)
                {^received_type, '*'} -> Map.put(acc, new_key, true)
                {^received_type, _} when received_subtype == '*' -> Map.put(acc, new_key, true)
                {'*', _} -> Map.put(acc, new_key, true)
                _ when received_type == '*' -> Map.put(acc, new_key, true)
                _ -> acc
              end

              # |> IO.inspect( label: "new map" )
            end)

          functor, acc ->
            functor.(acc, {received_type, received_subtype}, media_range_tuple)
        end)
      end)

      # |> IO.inspect(label: "Used accept maps")
    end)
  end

  defp sort_and_group_accept_headers(accept) do
    accept
    |> safe_parse_accept_header()
    |> IO.inspect(label: "parsed_accept_header")
    |> Enum.sort_by(&elem(&1, 3))
    |> Enum.group_by(&elem(&1, 3))
    |> Map.to_list()
    |> Enum.sort_by(&elem(&1, 0), &>=/2)
  end

  defp safe_parse_accept_header(accept_header) do
    try do
      case :accept_header.parse(accept_header) do
        [] -> :accept_header.parse("*/*")
        parsed_headers -> parsed_headers
      end
    rescue
      _ ->
        IO.inspect(accept_header, label: "Could not parse this accept header")
        :accept_header.parse("*/*")
    end
  end
end
