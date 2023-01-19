defmodule ExternalDns.Task do
  require Logger

  def start_link() do
    Task.start_link(__MODULE__, :loop, [])
  end

  def child_spec([]) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}, restart: :transient}
  end

  def loop() do
    ExternalDns.start()
  rescue
    e -> Logger.error("failed: #{inspect(e)}")
  after
    Process.sleep(:timer.minutes(5))
    loop()
  end
end
