defmodule Matcher do
  defmacro __using__(_opts) do
    quote do
      require Matcher
      import Matcher
      import Plug.Conn, only: [send_resp: 3]
      import Proxy, only: [forward: 3]

      def dispatch(conn) do
        Matcher.dispatch_call(
          conn,
          fn -> accept_types() end,
          fn a, b, c, d -> do_match(a, b, c, d) end
        )
      end
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
    quote do
      def do_match(_, _, _, _) do
        {:skip}
      end
    end
  end

  # Builds a method in the form of:
  #
  # def do_match( "GET", "/hello/erika/", %{ accept: %{} }, conn ) do
  #    ...
  # end
  defmacro match_method(call, path, options, do: block) do
    # Throw warning when strange conditions occur
    unless String.starts_with?(path, "/") do
      IO.puts "WARNING: invalid path: #{path} does not start with a `/`"
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

    # |> IO.inspect(label: "call name")

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

  defmacro define_accept_types(received_accept_types) do
    quote do
      def accept_types do
        unquote(received_accept_types)
      end
    end
  end

  # Call dispatching
  def dispatch_call(conn, accept_types, call_handler) do
    # Extract core info
    {method, path, accept_header, host} = extract_core_info_from_conn(conn)
    # |> IO.inspect(label: "extracted header")

    # Extract core request info
    accept_hashes =
      sort_and_group_accept_headers(accept_header)
      |> transform_grouped_accept_headers(accept_types)

    # |> IO.inspect(label: "accept hashes")

    # For each set of media types, go over the defined calls searching
    # for a handled response.
    first_run =
      accept_hashes
      |> Enum.find_value(fn accept ->
        options = %{accept: accept, host: host}

        case call_handler.(method, path, options, conn) do
          {:skip} -> nil
          conn -> conn
        end
      end)

    case first_run do
      nil ->
        # If no one handled the response, send out a last call for
        # response handling.
        # IO.puts("Going for last call")

        accept_hashes
        # |> IO.inspect(label: "Accept hashes for last call")
        |> Enum.find_value(fn accept ->
          options = %{accept: accept, host: host, last_call: true}

          # IO.inspect(method, label: "trying to call call_handler with method")
          # IO.inspect(path, label: "trying to call call_handler with path")
          # IO.inspect(options, label: "trying to call call_handler with options")
          # IO.inspect(conn, label: "trying to call call_handler with conn")

          case call_handler.(method, path, options, conn) do
            {:skip} -> nil
            conn -> conn
          end
        end)

      conn ->
        # This case is when we have received a connection
        conn
    end
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
    # |> IO.inspect(label: "parsed_accept_header")
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
