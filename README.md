# mu-dispatcher

The core request dispatcher for [semantic.works](https://semantic.works) stacks. Routes incoming HTTP requests to the appropriate microservice based on path, HTTP verb, `Accept` header, and hostname, using a configuration file written in Elixir.

## Getting started

This tutorial walks through adding `mu-dispatcher` to a [mu-project](https://github.com/mu-semtech/mu-project) and wiring up a backend API service alongside a frontend application.

### Add the dispatcher to a semantic.works stack

Add the dispatcher to `docker-compose.yml`

```yaml
dispatcher:
  image: semtech/mu-dispatcher:2.1.0
  volumes:
    - ./config/dispatcher:/config
```

Create a configuration file in `./config/dispatcher/dispatcher.ex`. This file must define an Elixir module named `Dispatcher` that uses the `Matcher` macro:

```elixir
defmodule Dispatcher do
  use Matcher
  define_accept_types []

  # routing rules go here
end
```

Extend the file to route JSON API requests to a `resource` microservice and serve an Ember frontend for all other HTML requests:

```elixir
defmodule Dispatcher do
  use Matcher

  define_accept_types [
    html: [ "text/html", "application/xhtml+html" ],
    json: [ "application/json", "application/vnd.api+json" ],
    any:  [ "*/*" ]
  ]

  match "/themes/*path", %{ accept: %{ json: true } } do
    forward conn, path, "http://resource/themes/"
  end

  match "/assets/*path", %{ accept: %{ any: true } } do
    forward conn, path, "http://frontend/assets/"
  end

  match "/*_path", %{ accept: %{ html: true } } do
    forward conn, [], "http://frontend/index.html"
  end

  match "/*_", %{ last_call: true, accept: %{ json: true } } do
    send_resp(conn, 404, ~s|{ "error": { "code": 404, "message": "Route not found." } }|)
  end
end
```

Start the stack

```bash
docker compose up -d dispatcher
```

The dispatcher now accepts and forwards connections to the configured services.

## How-to guides

### How to forward requests to a microservice

Use `forward` to proxy a request to an upstream service. The second argument is the list of remaining path segments captured by the `*path` wildcard. Pass an empty list `[]` to forward to the base URL without appending anything.

```elixir
# Forward /sessions and all sub-paths to the login service
match "/sessions/*path", _ do
  forward conn, path, "http://login/sessions/"
end

# Forward a single fixed endpoint
match "/health", _ do
  forward conn, [], "http://health/status"
end
```

### How to match on HTTP verb

Use the verb-specific macros `get`, `post`, `put`, `patch`, `delete`, `head`, or `options` instead of `match` to restrict a rule to a single method:

```elixir
post "/sessions", _ do
  forward conn, [], "http://login/sessions"
end

delete "/sessions", _ do
  forward conn, [], "http://login/sessions"
end
```

### How to match on Accept header

Define short aliases for groups of MIME types with `define_accept_types`, then use them in the `accept` option of a rule:

```elixir
defmodule Dispatcher do
  use Matcher

  define_accept_types [
    json: [ "application/json", "application/vnd.api+json" ],
    img: [ "image/jpg", "image/jpeg", "image/png" ],
    gif: [ "image/gif" ]
  ]

  get "/images/*path", %{ accept: %{ json: true } } do
    forward conn, path, "http://resource/images"
  end

  get "/images/*path", %{ accept: %{ img: true } } do
    forward conn, path, "http://images/images"
  end

  get "/images/*path", %{ accept: %{ gif: true } } do
    forward conn, path, "http://gifs/images"
  end
end
```

The first matching rule wins, so order matters.

### How to match on hostname

Use the `host` option to restrict a rule to a specific virtual host. A string value supports `*` wildcards. An array value lists domain parts in reverse order (TLD first) and allows capturing sub-domains as variables.

```elixir
# Exact match
get "/employees", %{ host: "api.example.com" } do
  forward conn, [], "http://employees/"
end

# Wildcard, matches api.example.com, dev.example.com, etc.
get "/employees", %{ host: "*.example.com" } do
  forward conn, [], "http://employees/"
end

# Array match with variable capture
get "/employees", %{ host: ["com", "example", subdomain | rest] } do
  IO.inspect(subdomain, label: "Subdomain")
  IO.inspect(rest, "Array of subdomains under subdomain" )
  forward conn, [], "http://employees/"
end
```

The array form requires at least the specified number of domain parts to be present, so `["com", "example", subdomain | _rest]` will not match `example.com` (no subdomain).

### How to serve a frontend Ember application

Serve all HTML requests from the frontend, route assets through a dedicated path, and direct API calls to backend services:

```elixir
defmodule Dispatcher do
  use Matcher

  define_accept_types [
    json: [ "application/json", "application/vnd.api+json" ],
    html: [ "text/html", "application/xhtml+html" ],
    any:  [ "*/*" ]
  ]

  @html %{ accept: %{ html: true } }
  @json %{ accept: %{ json: true } }
  @any  %{ accept: %{ any: true } }

  # all backend dispatching rules here
  # ...

  # static assets
  match "/assets/*path", @any do
    forward conn, path, "http://frontend/assets/"
  end

  # SPA catch-all
  match "/*_path", @html do
    forward conn, [], "http://frontend/index.html"
  end

  match "/*_", %{ last_call: true, accept: %{ json: true } } do
    send_resp( conn, 404, "{ \"error\": { \"code\": 404, \"message\": \"Route not found.  See config/dispatcher.ex\" } }" )  
  end
end
```

### How to handle CORS headers for cross-origin requests

Return the required CORS headers in response to browser preflight `OPTIONS` requests. Any 200 response makes the browsers accept those headers. Place this rule before any other rules that match the same paths:

```elixir
options "*path", _ do
  conn
  |> Plug.Conn.put_resp_header("access-control-allow-headers", "content-type,accept")
  |> Plug.Conn.put_resp_header("access-control-allow-methods", "*")
  |> send_resp(200, "{ \"message\": \"ok\" }")
end
```

### How to provide 404 fallback pages

Use `last_call: true` to define rules that only activate once no other rule has matched. Multiple fallback rules can serve different content types:

```elixir
define_accept_types [
  html: [ "text/html", "application/xhtml+html" ],
  json: [ "application/json", "application/vnd.api+json" ],
  text: [ "text/*" ],
  png:  [ "image/png" ]
]

get "/*_", %{ last_call: true, accept: %{ json: true } } do
  send_resp(conn, 404, ~s|{ "error": { "code": 404, "message": "Route not found." } }|)
end

get "/*_", %{ last_call: true, accept: %{ html: true } } do
  send_resp(conn, 404, "<html><body><h1>404 - Not found</h1></body></html>")
end

get "/*_", %{ last_call: true, accept: %{ text: true } } do
  send_resp(conn, 404, "404 - page not found\n\nSee config/dispatcher.ex")
end

get "/*_", %{ last_call: true, accept: %{ png: true } } do
  forward conn, [], "http://static/404.png"
end
```

### How to use layers to organise routing rules

Layers partition route evaluation into ordered phases. All rules in the first layer are evaluated before any rule in the second layer is considered. Within a layer, top-to-bottom order still applies.

```elixir
define_layers [ :api, :frontend ]

define_accept_types [
  html: [ "text/html", "application/xhtml+html" ],
  json: [ "application/json", "application/vnd.api+json" ]
]

match "/*path", %{ accept: %{ json: true }, layer: :api } do
  forward conn, path, "http://resource/"
end

match "/*path", %{ accept: %{ html: true }, layer: :frontend } do
  forward conn, path, "http://frontend/"
end
```

This is useful when API rules must take precedence over frontend catch-all rules regardless of how the rules are ordered in the file.

### How to add inline logic before forwarding

The rule body is plain Elixir, so you can log, inspect, or modify the connection before forwarding. Module attributes can consolidate repeated option maps:

```elixir
@json %{ accept: %{ json: true } }

match "/sessions/*path", @json do
  IO.inspect(conn, label: "conn for /sessions")
  forward conn, path, "http://sessions/login"
end

match "/images/*path", @json do
  forward conn, path, "http://resource/images"
end
```

## Reference

### Environment variables

The following environment variables can be configured on the service.

| Variable | Description | Default |
|---|---|---|
| `MAX_URL_LENGTH` | Maximum permitted URL length in bytes. Requests with a longer URL are rejected by the HTTP server before reaching the dispatcher. | `10000` |
| `IDLE_TIMEOUT` | Idle connection timeout in milliseconds. Connections that carry no traffic for this duration are closed. | `300000` |
| `LOG_BACKEND_COMMUNICATION` | Log raw communication with upstream services (`true`/`false`). | `false` |
| `LOG_FRONTEND_COMMUNICATION` | Log raw communication with downstream clients (`true`/`false`). | `false` |
| `LOG_FRONTEND_PROCESSING` | Log request processing steps (`true`/`false`). | `false` |
| `LOG_BACKEND_PROCESSING` | Log response processing steps (`true`/`false`). | `false` |
| `LOG_CONNECTION_SETUP` | Log connection setup details (`true`/`false`). | `false` |
| `LOG_REQUEST_BODY` | Log request bodies (`true`/`false`). | `false` |
| `LOG_RESPONSE_BODY` | Log response bodies (`true`/`false`). | `false` |
| `LOG_AVAILABLE_LAYERS` | Log the set of available layers on each request (`true`/`false`). | `false` |
| `LOG_LAYER_START_PROCESSING` | Log when a layer starts being evaluated (`true`/`false`). | `false` |
| `LOG_LAYER_MATCHING` | Log whether each layer produced a match (`true`/`false`). | `false` |

Boolean environment variables accept `true`, `yes`, `1`, or `on` (case-insensitive) as truthy values.

All `LOG_*` variables are experimental and only there for debugging purposes. They may be added or removed in future non-major releases.

### Dispatcher rules

The dispatcher is configured by an Elixir module placed at `/config/dispatcher.ex` (mounted in the Docker container). The module must be named `Dispatcher` and must use the `Matcher` macro.

#### Module skeleton

```elixir
defmodule Dispatcher do
  use Matcher
  define_accept_types []

  # routing rules
end
```

`use Matcher` imports the matcher and makes `forward`, `send_resp`, and all route macros available inside the module.

#### `define_accept_types`

Declares short aliases that map to lists of MIME types. Wildcards (`*`) are permitted.

```elixir
define_accept_types [
  json: [ "application/json", "application/vnd.api+json" ],
  html: [ "text/html", "application/xhtml+html" ],
  any:  [ "*/*" ]
]
```

Accept type aliases are used in route options as `%{ accept: %{ json: true } }`.

Raw MIME type matching is fragile. A browser typically sends `text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8` in a single `Accept` header, and a JSON:API client may send `application/vnd.api+json` while a rule was written for `application/json`. The `define_accept_types` mechanism decouples the MIME types that clients send from the identifiers used inside routing rules. A rule tagged with `%{ accept: %{ json: true } }` fires for any request whose best acceptable MIME type overlaps with the list declared under `json:`, regardless of how specific or generic the client's header is.

#### `define_layers`

Declares an ordered list of evaluation layers. Rules are assigned to a layer with the `layer:` option.

```elixir
define_layers [ :api, :frontend ]
```

Layers are used in route options as `%{ layer: :frontend }`.

Order matters: layers listed first are evaluated first.

Without layers, rules are evaluated strictly from top to bottom and the first match wins. Layers partition this evaluation into phases. All rules in the first layer are tried before any rule in the second layer is considered. Within each layer top-to-bottom order still applies. This is useful when you need to guarantee that API rules always take precedence over frontend catch-all rules even when the configuration file interleaves them, or when different teams contribute independent sets of rules that need to compose predictably.

#### Route matchers

The following macros match an incoming request. The first matching rule in evaluation order wins.

| Macro | Matched HTTP methods |
|---|---|
| `match` | all |
| `get` | GET |
| `post` | POST |
| `put` | PUT |
| `patch` | PATCH |
| `delete` | DELETE |
| `head` | HEAD |
| `options` | OPTIONS |

**Syntax**

```elixir
<verb> <path_pattern>, <options> do
  # body — plain Elixir with access to `conn` and captured `path`
end
```

- **`path_pattern`**: a string such as `"/themes/*path"`. The `*path` segment captures all remaining path components as a list into the variable `path`. Use `*_` or `*_name` to capture and discard remaining segments.
- **`options`**: an Elixir map or `_` to match unconditionally.
- **`conn`**: the [Plug.Conn](https://hexdocs.pm/plug/Plug.Conn.html) struct, available inside the body.
- **`path`**: the captured path list, available inside the body when `*path` is used in the pattern.

**Route options**

| Key | Type | Description |
|---|---|---|
| `accept` | `%{ json: true }` | Only match if the request `Accept` header includes a MIME type covered by the given alias from `define_accept_types`. |
| `host` | `String` or `[String]` | Only match if the request `Host` header satisfies the given value. String form supports `*` wildcards. Array form lists domain parts in reverse order (TLD first) and allows variable capture. |
| `layer` | atom | Assign this rule to the named layer defined with `define_layers`. |
| `last_call` | `true` | Only evaluate this rule after all non-`last_call` rules have failed to match. Used for fallback and 404 responses. |

#### Request forwarding

Request forwarding is built on top of [plug_mint_proxy](https://github.com/madnificent/plug-mint-proxy), which uses the [Mint](https://github.com/elixir-mint/mint) library to make efficient upstream HTTP connections. Incoming connections are accepted by [Cowboy 2](https://github.com/ninenines/cowboy), which supports both HTTP/1.1 and HTTP/2. The dispatcher is wired into the Plug pipeline in [plug_router_dispatcher.ex](./lib/plug_router_dispatcher.ex).

##### `forward/3`

Proxies the request to an upstream URL and streams the response back.

```elixir
forward conn, path, "http://service/base-path/"
```

- **`conn`**: the connection struct.
- **`path`**: list of path segments to append to the base URL. Pass `[]` to forward to the base URL without appending anything.
- **`url`**: base URL of the upstream service (string). Make sure the `url` ends with a trailing slash `/` if path segments will be appended.

##### `send_resp/3`

Sends an immediate response without forwarding to an upstream service.

```elixir
send_resp(conn, status_code, body)
```

Standard [Plug.Conn.send_resp/3](https://hexdocs.pm/plug/Plug.Conn.html#send_resp/3).

### Automatic header manipulation
The dispatcher knows about certain header manipulations to smoothen out configuration. These are configured using `plug_mint_proxy`'s manipulators as seen in [the Proxy module](https://github.com/mu-semtech/mu-dispatcher/blob/master/lib/proxy.ex).

| Manipulator | Applied to | Description |
|---|---|---|
| `AddXRewriteUrlHeader` | Outgoing request | Adds `x-rewrite-url` containing the original request URL so backend services can reconstruct it if needed. |
| `RemoveAcceptEncodingHeader` | Outgoing request | Strips `accept-encoding` because compression is handled at the edge and must not be negotiated by backend services. |
| `AddVaryHeader` | Incoming response | Adds `Vary: accept, cookie` so intermediate caches consider both the `Accept` header and session cookie when storing responses. |

### Request dispatching algorithm

Incoming requests are matched against routing rules as follows:

1. Parse the request `Accept` header and group MIME types by quality score (highest first).
2. For each quality group, determine which `define_accept_types` aliases overlap with the requested MIME types.
3. Work through each alias and try every rule (in definition order, within the current layer) that matches the path, host, verb, and that alias. Return on the first match.
4. If layers are defined, advance to the next layer and repeat step 3.
5. If no rule matched, repeat steps 2-4 considering only rules with `last_call: true`.
6. If still no match, return a 500 response.






