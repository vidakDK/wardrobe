defmodule Clothes.System do
  def start_link do
    Supervisor.start_link(
      [
        Clothes.ProcessRegistry,
        Clothes.Database,
        Clothes.Cache
        # Clothes.Web
        # Clothes.Metrics
      ],
      strategy: :one_for_one
    )
  end
end
