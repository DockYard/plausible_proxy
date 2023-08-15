defmodule PlausibleProxy.Plug do
  @moduledoc """

  Plug Opts:
      local_path: "/some_path.js" (defaults to "/js/plausible_script.js")
      script_extension: "script.local.js" (defaults to "script.js") See: https://plausible.io/docs/script-extensions#all-our-script-extensions
      remote_ip_headers: ["foo"] (defaults to ["fly-client-ip", "x-real-ip"])
      event_callback_fn: Optional callback function when an event fires that receives the conn, payload, and remote_ip
                        and returns {:ok, payload_modifiers}. payload_modifiers is a map
                              Supported payload_modifiers:
                                props: map of values to pass in the "props" value of the body
                                        e.g. %{"company" => "DockYard"}

  """
  @behaviour Plug

  require Logger

  import Plug.Conn

  @default_local_path "/js/plausible_script.js"

  @impl Plug
  def init(opts) do
    %{
      event_callback_fn: Keyword.get(opts, :event_callback_fn, fn _conn, _payload, _remote_ip -> {:ok, %{}} end),
      local_path: Keyword.get(opts, :local_path, @default_local_path),
      script_extension: Keyword.get(opts, :script_extension, "script.js"),
      remote_ip_headers: Keyword.get(opts, :remote_ip_headers, ["fly-client-ip", "x-real-ip"])
    }
  end

  defp script(%{script_extension: ext}), do: "https://plausible.io/js/#{ext}"

  @impl Plug
  def call(%{request_path: path} = conn, %{local_path: path} = opts) do
    Logger.warn("Loading script for path #{path} from #{script(opts)}")
    remote_ip_address = determine_ip_address(conn, opts)
    headers = build_headers(conn, remote_ip_address)

    case HTTPoison.get(script(opts), headers) do
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
         {:ok, payload} <- Jason.decode(body),
         remote_ip_address = determine_ip_address(conn, opts),
         {:ok, payload_modifiers} <- opts.event_callback_fn.(conn, payload, remote_ip_address),
         {:ok, resp} <- post_event(conn, payload, remote_ip_address, payload_modifiers) do
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

  defp build_headers(conn, ip_address, optional_headers \\ []) do
    user_agent = get_one_header(conn, "user-agent")

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

  def determine_ip_address(conn, %{remote_ip_headers: remote_ip_headers}) do
    Enum.find(remote_ip_headers, &get_one_header(conn, &1)) ||
      List.to_string(:inet.ntoa(conn.remote_ip))
  end

  defp post_event(conn, payload, remote_ip_address, payload_modifiers) do
    headers = build_headers(conn, remote_ip_address, [{"Content-Type", "application/json"}])

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
