defmodule PlausibleProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :plausible_proxy,
      version: "0.1.1",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: source_url()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def description do
    "A plug to proxy requests to Plausible"
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/DockYard/plausible_proxy"}
    ]
  end

  defp source_url do
    "https://github.com/DockYard/plausible_proxy"
  end

  defp elixirc_paths(:test), do: elixirc_paths(nil) ++ ["test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:plug, "~> 1.11"},
      {:httpoison, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.30.5", only: :dev, runtime: false}
    ]
  end
end
