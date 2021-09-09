# mu-dispatcher

Core microservice for dispatching requests to the preferred microservice.

The mu-dispatcher is one of the core elements in the mu.semte.ch architecture.  This service will dispatch requests to other microservices based on the incoming request path.  You can run the service through docker, but you probably want to configure it using [mu-project](http://github.com/mu-semtech/mu-project) so it uses your own configuration.

The Dispatcher runs as an application in which the `Dispatcher` module is overridden.  It expects a dispatcher.ex file to exist on `/config/dispatcher.ex` when the dispatcher boots up.

# Table of Contents
1. [Configuration](#Configuration)
2. [Supported API](#Supported-API)
    1. [Matcher](#Use-Matcher)
    2. [Http Verbs](#Http-verbs)
    3. [define_accept_types](#define_accept_types)
3. [forwarding requests](#Forwarding-requests)
    1. [Basic forwarding](#Basic-forwarding)
    2. [Forwarding paths](#Forwarding-paths)
    3. [Matching on verb](#Matching-on-verb)
    4. [Matching on host](#Matching-on-host)
    5. [Matching Accept headers](#Matching-Accept-headers)
4. [Fallback routes and 404 pages](#Fallback-routes-and-404-pages)
5. [Manipulating responses](#Manipulating-responses)
6. [How-to / Extra information](#Extra-information)
    1. [Host an EmberJS app](#Host-an-EmberJS-app)
    2. [External API CORS headers](#External-API-CORS-headers)
    3. [Provide 404 pages](#Provide-404-pages)
7. [Architecture](#Architecture)
    1. [forwarding connections with plug_mint_proxy](#Forwarding-Connections)
    2. [Wiring with Plug](#Wiring-with-Plug)
    3. [Header manipulation](#Header-manipulation)
    4. [Matcher](#Matcher)

### Configuration

The disptacher is configured using the dispatcher.ex file in a [mu-project](https://github.com/mu-semtech/mu-project).

The basic (default) configuration of the mu-dispatcher is an Elixir module named `Dispatcher` which uses the `Matcher` functionality.
An empty set of accept types is required (`define_accept_types []`).

```elixir
defmodule Dispatcher do
  use Matcher
  define_accept_types []

  ...
end
```

### Supported API

#### Use Matcher

The using Matcher macro sets up the matcher.  It imports Matcher, send_resp and forward.

### Http verbs
### `get`, `put`, `post`, `delete`, `patch`, `head`, `options`, `match`

Implements a specific matcher on the http verb with the corresponding name.  The `match` macro matches all verbs.

```Accepts:```

  - path: A string which is deconstructed into variables.
  - options: The options hash containing options to match on for this call:
    - accept: hash with all required accept shortforms analyzed through `define_accept_types`
    - last_call: set to true when searching for a fallback solution (for sending a clean 404)
  - block: Code block for processing and sending the request

```Supplies:```

  - conn: Plug connection to be forwarded or responded to
  - path: Often the `path` as input is set as `"/something/*path"` in which case the `path` variable contains unused path segments

### define_accept_types

Provides a way to match the accept types to more readable terms so matching can happen in an easy and consistent manner.  Receives a property array describing each of the keys that will be used and their corresponding accept headers.  Wildcards are allowed in this specification.


## Forwarding requests

### Basic forwarding

You can proxy one path to another path using this service.
In order to forward requests coming in on `/sessions` to `http://sessionsservice/login`, we can add the following.

```elixir
defmodule Dispatcher do
  use Matcher
  define_accept_types []

  match "/sessions", _ do
    forward conn, [], "http://sessionsservice/login"
  end
end
```

This uses the match macro to match any verb, it ignores any extra info, and it forwards the connection to the sessionsservice.  The body is just Elixir code, hence we can add any extra logic in here if need be.  An example would be to log the conn we receive when forwarding.

```elixir
defmodule Dispatcher do
  use Matcher
  define_accept_types []

  match "/sessions", _ do
    IO.inspect( conn, label: "conn for /sessions" )
    forward conn, [], "http://sessionsservice/login"
  end
end
```

### Forwarding paths

In many cases it is desired to verbatim forward all subroutes of a route.  A common case would be to dispatch the handling of some resource through mu-cl-resources.  We can forward any call to widgets this way.

```elixir
defmodule Dispatcher do
  use Matcher
  define_accept_types []

  match "/widgets/*path", _ do
    forward conn, path, "http://resource/widgets"
  end
end
```

This match will forward any verb on any path that begins with `/widgets` to the [resource](http://github.com/mu-semtech/mu-cl-resources) microservice.


### Matching on verb

It is possible to explicitly match on an HTTP verb.  Supported verbs are GET, PUT, POST, DELETE, HEAD, OPTIONS.  Use the downcased name of the verb as a matching construct.  In order to only forward POST requests, we would update our sample to the following:

```elixir
defmodule Dispatcher do
  use Matcher
  define_accept_types []

  post "/sessions", _ do
    forward conn, [], "http://sessionsservice/login"
  end
end
```


### Matching Accept headers

It is important to only dispatch to services which can formulate an acceptable response.  This ensures the best response for the user is selected.

Clients can request content in many formats.  These formats are expressed using MIME types.  Common mime types on the web are are `application/json`, `text/html`, `image/jpeg` and (for {JSON:API}) `application/vnd.api+json`.  Star patterns are allowed in mime types, allowing for `image/*` or just `*/*` to be requested.  A browser can supply many MIME types for a single request with differing preferences, allowing it to state "I would like to have an image, but a web page will do if you don't have the image."

When responding to a request, we should respond with applicable content.  If the browser requests an image, we should yield an image rather than a json representation of that image.  A non-functional example could look like this.

```elixir
# THIS DOES NOT WORK!
defmodule Dispatcher do
  use Matcher
  define_accept_types []

  match "/images/*path", %{ accept: "image/jpeg" } do
    forward conn, path, "http://images/"
  end

  match "/images/*path", %{ accept: "application/json" } do
    forward conn, path, "http://resource/images/"
  end
end
```

In practice we tend to build abstractions on these MIME types.  Resources responds with `application/vnd.api+json` which matches the specification for `application/json`.  Hence, we'd want that service to respond to both of these.  Abstractions of these settings are made using accept types abstractions as shown in the following example.

```elixir
defmodule Dispatcher do
  use Matcher

  define_accept_types [
    json: [ "application/json", "application/vnd.api+json" ]
  ]

  match "/images/*path", %{ accept: %{ json: true } } do
    forward conn, path, "http://resource/images"
  end
end
```

A more convoluted example contains the hosting of images.  We may have an image hosting/scaling/conversion service that supports JPEG and PNG, another service for handling GIFs.  A full example would then look like the following:

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

In this configuration the first case that matches wins.  If the user prefers json that's what they'll get, the same for gif or jpeg.

### Matching on host

Dispatching may occur based on a hostname.  Both an array-format as well as a string-format are supported to match on a host.  The string-format currently supports matching only, the array format also allows extraction.

In order to reply only to calls coming in for `api.redpencil.io`, you can use the rule:

```elixir
  get "/employees", %{ host: ["io", "redpencil", "api"] } do
    ...
  end
```

Or, for simple matches like this, you can use a simplified API like:

```elixir
  get "/employees", %{ host: "api.redpencil.io" } do
    ...
  end
```

This simplified syntax is internally converted into an array match.  Wildcards are supported too:

```elixir
  get "/employees", %{ host: "*.redpencil.io" } do
    ...
  end
```

This wildcard will match `redpencil.io`, `api.redpencil.io`, `dev.api.redpencil.io`, etc.

If you need to access a part of the API, revert back to the array syntax and define a variable:

```elixir
  get "/employees", %{ host: ["io", "redpencil", subdomain | subsubdomains] }
    IO.inspect( subdomain, "First subdomain" )
    IO.inspect( subsubdomains, "Array of subdomains under subdomain" )
    ...
  end
```

This specific implementation does require at least one subdomain and it will thus not match `redpencil.io`.

### Forwarding websockets

Dispatcher can forward websocket tunnels.

An example rule is as follows:

```elixir
  match "/websocket" do
    ws(conn, "ws://localhost:7999")
  end
```

Any websocket connections on `/websocket` get's redirected to `/ws?target=<something>`.
The Gun library listens to websockets on `/ws` which makes everything work.
The `target` query parameter tells Gun what host to forward to.


Note: following redirects is not required in the websockets specs, and most browsers don't support this.

Example workarounds:
```js
async function createRedirectedWebsocket(url) {
    // This prints an error to the console due to unexpected upgrade response
    const resp = await fetch(url);
    const ws_url = resp.url.replace(/^http/, 'ws');
    return new WebSocket(ws_url);
}
```

With the 'ws' npm package it is possible to set a `followRedirects` flag.
```js
const WebSocket = require('ws')
const ws = new WebSocket('ws://localhost/ws2', options={'followRedirects': true});
```

### Fallback routes and 404 pages

When no response can be given, a 404 page should be provided.  This 404 page should only be offered when no other service could answer the request.  Hence we should only serve the 404 page when all other services have had their go.  The format of the 404 page follows the same accept header rules as the actual content so the same flow holds.

In order to provide a 404 page or other fallback, the `last_call` option is supplied on which you can filter.  Extending our previous example with json, html, a 404 page in all sorts of images gives us the following result.

```elixir
defmodule Dispatcher do
  use Matcher

  define_accept_types [
    text: [ "text/*" ],
    html: [ "text/html", "application/xhtml+html" ],
    json: [ "application/json", "application/vnd.api+json" ],
    img: [ "image/jpg", "image/jpeg", "image/png" ],
    gif: [ "image/gif" ],
    image: [ "image/*" ]
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

  get "/*_", %{ last_call: true, accept: %{ json: true } } do
    send_resp( conn, 404, "{ \"error\": { \"code\": 404, \"message\": \"Route not found.  See config/dispatcher.ex\" } }" )
  end

  get "/*_", %{ last_call: true, accept: %{ image: true } } do
    forward conn, [], "http://images/404"
  end

  get "/*_", %{ last_call: true, accept: %{ text: true } } do
    send_resp( conn, 404, "404 - page not found\n\nSee config/dispatcher.ex" )
  end

  get "/*_", %{ last_call: true, accept: %{ html: true } } do
    send_resp( conn, 404, "<html><head><title>404 - Not Found</title></head><body><h1>404 - Page not found</h1></body></html>" )
  end
end
```

### Manipulating responses

The dispatcher is just code.  As you start reusing the same properties more often, you may want to supply default values to clean things up.  You can also add conditional logging, or manipulate the request before forwarding it to the client.

Although not considered a public API, it is possible to manipulate the request or to draft responses manually.

```elixir
defmodule Dispatcher do
  use Matcher

  define_accept_types [
    json: [ "application/json", "application/vnd.api+json" ]
  ]

  @json %{ accept: %{ json: true } }

  match "/sessions/*path", @json do
    IO.inspect( conn, label: "Connection for sessions service." )
    forward conn, path, "http://sessions/login"
  end

  match "/images/*path", @json do
    forward conn, path, "http://resource/images"
  end

  match "/*_", %{ last_call: true, accept: %{ json: true } } do
    send_resp( conn, 404, "{ \"error\": { \"code\": 404, \"message\": \"Route not found.  See config/dispatcher.ex\" } }" )
  end
end
```

## Extra information

This section contains various recipes to implement specific behaviour with basic explanation as to why it works.

### Host an EmberJS app

The Ember application should be served on most calls when an HTML page is requested.  The assets and styles should be served on the respective paths whenever they are requested.

```elixir
defmodule Dispatcher do
  use Matcher

  define_accept_types [
    json: [ "application/json", "application/vnd.api+json" ],
    html: [ "text/html", "application/xhtml+html" ],
    any: [ "*/*" ]
  ]

  @html %{ accept: %{ html: true } }
  @json %{ accept: %{ json: true } }
  @any %{ accept: %{ any: true } }

  ... # your other rules belong here

  match "/assets/*path", @any do
    forward conn, path, "http://frontend/assets/"
  end

  match "/*_path", @html do
    # *_path allows a path to be supplied, but will not yield
    # an error that we don't use the path variable.
    forward conn, [], "http://frontend/index.html"
  end

  match "/*_", %{ last_call: true, accept: %{ json: true } } do
    send_resp( conn, 404, "{ \"error\": { \"code\": 404, \"message\": \"Route not found.  See config/dispatcher.ex\" } }" )
  end
end
```

### External API CORS headers

When using the dispatcher with a frontend running on another domain, browsers need to know what headers they can pass to your service.  In order to verify what headers are allowed, they send an options call.  We can hook into this options call to set the necessary headers.  Any 200 response makes the browsers accept those headers.

```elixir
defmodule Dispatcher do
  use Matcher
  define_accept_types []

  options "*path", _ do
    conn
    |> Plug.Conn.put_resp_header( "access-control-allow-headers", "content-type,accept" )
    |> Plug.Conn.put_resp_header( "access-control-allow-methods", "*" )
    |> send_resp( 200, "{ \"message\": \"ok\" }" )
  end
end
```

### Provide 404 pages

You can provide many types of 404 pages.  If you use a Single Page Application, you may want to default to the 404 page using the single page app.  You may want to provide a 404 json response in any case.  The same holds for other formats.

The following example hosts 404 pages in various types assuming there is a `static` microservice that hosts static assets for you.  Note that the HTML 404 option may be served by your backend instead.

```elixir
defmodule Dispatcher do
  use Matcher

  define_accept_types [
    text: [ "text/*" ],
    html: [ "text/html", "application/xhtml+html" ],
    json: [ "application/json", "application/vnd.api+json" ],
    jpeg: [ "image/jpg", "image/jpeg" ],
    png: [ "image/png" ],
    gif: [ "image/gif" ],
  ]

  ... # other calls here

  get "/*_", %{ last_call: true, accept: %{ json: true } } do
    send_resp( conn, 404, "{ \"error\": { \"code\": 404, \"message\": \"Route not found.  See config/dispatcher.ex\" } }" )
  end

  get "/*_", %{ last_call: true, accept: %{ text: true } } do
    send_resp( conn, 404, "404 - page not found\n\nSee config/dispatcher.ex" )
  end

  get "/*_", %{ last_call: true, accept: %{ html: true } } do
    send_resp( conn, 404, "<html><head><title>404 - Not Found</title></head><body><h1>404 - Page not found</h1></body></html>" )
  end

  get "/*_", %{ last_call: true, accept: %{ jpeg: true } } do
    forward conn, [], "http://static/404.jpeg"
  end

  get "/*_", %{ last_call: true, accept: %{ png: true } } do
    forward conn, [], "http://static/404.png"
  end

  get "/*_", %{ last_call: true, accept: %{ gif: true } } do
    forward conn, [], "http://static/404.gif"
  end
end
```

## Architecture

The Dispatcher offers support for forwarding connections and for dispatching connections.

### Forwarding Connections

Forwarding connections is built on top of `plug_mint_proxy` which uses the Mint library for efficient creation of requests.  Request accepting is based on Cowboy 2 which allows for http/2 support.

### Wiring with Plug
[Plug](https://github.com/elixir-plug/plug) expects call to be matched using its own matcher and dispatcher.
This library provides some extra support.
Although tying this in within Plug might be simple, the request is dispatched to our own matcher in [plug_router_dispatcher.ex](./lib/plug_router_dispatcher.ex).

### Header manipulation

The dispatcher knows about certain header manipulations to smoothen out configuration.  These are configured using `plug_mint_proxy`'s manipulators as seen in [the Proxy module](./lib/proxy.ex)

  - [Manipulators.AddXRewriteUrlHeader](./lib/manipulators/add_x_rewrite_url_header.ex): Sets the x-rewrite-url header on the incoming request so backend services can figure out tho original request if needed.
  - [Manipulators.RemoveAcceptEncodingHeader](./lib/manipulators/remove_accept_encoding_header.ex): Removes the `accept_encoding` header from the request as encryption is handled by the identifier and should not be hanlded by backend services.
  - [Manipulators.AddVaryHeader](./lib/add_vary_header.ex): Adds the `vary` header with value `"accept, cookie"` so both of these are taken into account during incidental caching in between links or the user's browser.

### Matcher

[The Matcher module](./lib/matcher.ex) contains the bulk of the logic in this component.  It parses the request Accept header and parses the accept types inside of it.  It also parses the supplied accept types and searches for an optimal solution to dispatch to.

High-level the dispatching works as follows:

1. Parse the accept header
2. Group each score of the accept header (A)
3. Match each (A) with the set of `define_accept_types` noting that a `*` wildmatch may occur in both, thus resulting in (B).
4. For each (B) try to find a matched solution
5. If a solution is found, return it
6. If no solution is found, try to find a matched solution with the `last_call` option set to true
