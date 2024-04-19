defmodule PlausibleProxy.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  setup do
    {:ok, conn: build_conn()}
  end

  # https://github.com/phoenixframework/phoenix/blob/bdc2d7398ac51514d964e02e302515d2ce95b6ff/lib/phoenix/test/conn_test.ex#L151C1-L156C1
  defp build_conn do
    conn =
      Plug.Adapters.Test.Conn.conn(%Plug.Conn{}, :GET, "/", %{})
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, true)
      |> Plug.Conn.put_private(:phoenix_recycled, true)

    # remove headers injected by `Test.Conn` to avoid conflicts on actual tests
    %{conn | resp_headers: []}
  end
end
