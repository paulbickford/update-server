defmodule UpdateServer.MixProject do
  use Mix.Project

  @app :update_server

  def project do
    [
      app: :update_server,
      version: "0.1.0",
      elixir: "~> 1.13.2",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_env: [release: :prod],
      aliases: [
        rb: [
          "clean",
          "release"
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :public_key, :ssh],
      mod: {UpdateServer, []}
    ]
  end

  defp deps do
    [
      {:bakeware, "~> 0.2.2", runtime: false},
      {:credo, "~> 1.6.2", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:json, "~> 1.4"},
      {:ex_doc, "~> 0.28.0"},
      {:scenic, "~> 0.11.0-beta.0"},
      {:scenic_driver_local, "~>0.11.0-beta.0", targets: :host},
      {:type_check, "~> 0.10.6"}
    ]
  end

  defp release do
    [
      overwrite: true,
      quiet: true,
      steps: [:assemble, &Bakeware.assemble/1, &copy_to_system/1],
      strip_beams: Mix.env() == :prod
    ]
  end

  defp copy_to_system(release_struct) do
    System.cmd("sudo", [
      "cp",
      "-T",
      "_build/prod/rel/bakeware/update_server",
      "/usr/local/bin/update-server"
    ])

    IO.puts("Copied binary to /usr/local/bin/update-server")
    release_struct
  end
end
