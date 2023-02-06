defmodule PlausibleProxyTest do
  use ExUnit.Case
  doctest PlausibleProxy

  test "greets the world" do
    assert PlausibleProxy.hello() == :world
  end
end
