defmodule PlausibleProxy.Plug do
  @moduledoc """
  Application vars:

      config :plausible_proxy,
        local_path: "some_path.js" (defaults to "/js/plausible_script.js")
        allow_local: true (defaults to false) https://plausible.io/docs/script-extensions#all-our-script-extensions
        remote_ip_headers: ["foo"] (defaults to ["fly-client-ip", "x-real-ip"])

  Plug Opts:
      event_callback_fn: Optional callback function when an event fires that receives the conn and payload
                        and returns {:ok, payload_modifiers}. payload_modifiers is a map
                        Supported payload_modifiers:
                          props: map of values to pass in the "props" value of the body
                                 e.g. %{"company" => "DockYard"}

  """
  @behaviour Plug

  require Logger

  import Plug.Conn

  @default_local_path "/js/plausible_script.js"

  @local_path Application.compile_env(:plausible_proxy, :local_path, @default_local_path)

  @local if Application.compile_env(:plausible_plug, :allow_local, false), do: ".local", else: ""

  @script "https://plausible.io/js/script.tagged-events.pageview-props#{@local}.js"

  @impl Plug
  def init(opts) do
    %{event_callback_fn: Keyword.get(opts, :event_callback_fn, fn _conn, _payload -> {:ok, %{}} end)}
  end

  @impl Plug
  def call(%{request_path: @local_path} = conn, _opts) do
    headers = build_headers(conn)

    case HTTPoison.get(@script, headers) do
      {:ok, resp} ->
        conn
        |> prepend_resp_headers(resp.headers)
        |> send_resp(resp.status_code, resp.body)
        |> halt()

      _ ->
        conn
    end
  end

  def call(%Plug.Conn{request_path: "/api/event"} = conn, opts) do
    with {:ok, body, conn} <- read_body(conn),
         {:ok, payload} <- Jason.decode(body) |> IO.inspect(),
         {:ok, payload_modifiers} <- opts.event_callback_fn.(conn, payload),
         {:ok, resp} <- post_event(conn, payload, payload_modifiers) do
      conn
      |> prepend_resp_headers(resp.headers)
      |> send_resp(resp.status_code, resp.body)
      |> halt()
    else
      _error ->
        conn
        |> send_resp(500, "Reverse Proxy failed")
        |> halt()
    end
  end

  @impl Plug
  def call(conn, _) do
    conn
  end

  defp build_headers(conn, optional_headers \\ []) do
    user_agent = get_one_header(conn, "user-agent")
    ip_address = determine_ip_address(conn)

    [
      {"X-Forwarded-For", ip_address},
      {"User-Agent", user_agent}
      | optional_headers
    ]
  end

  defp get_one_header(conn, header_key) do
    conn
    |> Plug.Conn.get_req_header(header_key)
    |> List.first()
  end

  def determine_ip_address(conn) do
    Enum.find(remote_ip_headers(), &get_one_header(conn, &1)) ||
      List.to_string(:inet.ntoa(conn.remote_ip))
  end

  defp remote_ip_headers do
    Application.get_env(:plausible_proxy, :remote_ip_headers, ["fly-client-ip", "x-real-ip"])
  end

  defp post_event(conn, payload, payload_modifiers) do
    headers = build_headers(conn, [{"Content-Type", "application/json"}])

    body = %{
      "name" => payload["n"],
      "url" => payload["u"],
      "domain" => payload["d"]
    }

    body =
      case payload_modifiers do
        %{props: props} -> Map.put(body, "props", props)
        _ -> body
      end

    case HTTPoison.post("https://plausible.io/api/event", Jason.encode!(body), headers) do
      {:ok, resp} ->
        {:ok, resp}

      {:error, error} ->
        message = """
        failed to post Plausible event

        Got:

          #{inspect(error)}

        """

        Logger.error(message)

        {:error, error}
    end
  end
end
