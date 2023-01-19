defmodule ExternalDns.MixProject do
  use Mix.Project

  def project() do
    [
      app: :external_dns,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {ExternalDns.Application, []}
    ]
  end

  defp deps() do
    [
      {:certifi, "~> 2.10"},
      {:jason, "~> 1.4"}
    ]
  end
end
