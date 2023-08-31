# PlausibleProxy

1.  Add plausible_proxy to your mix dependencies

```elixir
def deps do
  [
    {:plausible_proxy, "~> 0.1.1"}
  ]
end
```

2.  Add PlausibleProxy.Plug to your Endpoint before your router:

```elixir
defmodule MyAppWeb.Endpoint do
  ...
  plug PlausibleProxy.Plug
  ...
  plug MyAppWeb.Router
end
```

3.  Add a script tag to your site referencing the local path:

```html
<script
  defer
  data-domain="{MyAppWeb.Endpoint.config(:url)[:host]}"
  src="/js/plausible_script.js"
></script>
```

See [PlausibleProxy.Plug](https://hexdocs.pm/plausible_proxy/PlausibleProxy.Plug.html) for optional configuration.
