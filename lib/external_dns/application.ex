defmodule ExternalDns.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([ExternalDns.Task], strategy: :one_for_one, name: __MODULE__)
  end
end
