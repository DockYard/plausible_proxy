defmodule PlausibleProxy.PlugTest do
  use PlausibleProxy.ConnCase
  alias Plug.Conn

  describe "merge_headers" do
    test "merged headers overwrites conn headers", %{conn: conn} do
      assert %Conn{resp_headers: [{"content-type", "text/javascript"}]} =
               PlausibleProxy.Plug.merge_resp_headers(%{conn | resp_headers: [{"Content-type", "text/plain"}]}, [{"Content-Type", "text/javascript"}])
    end

    test "lowercases keys", %{conn: conn} do
      assert %Conn{resp_headers: [{"content-type", "text/plain"}]} =
               PlausibleProxy.Plug.merge_resp_headers(%{conn | resp_headers: [{"Content-Type", "text/plain"}]}, [{"content-type", "text/plain"}])

      assert %Conn{resp_headers: [{"content-type", "text/plain"}]} =
               PlausibleProxy.Plug.merge_resp_headers(%{conn | resp_headers: [{"content-type", "text/plain"}]}, [{"Content-Type", "text/plain"}])
    end
  end
end
