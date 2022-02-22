import Config

config :scenic, :assets, module: UpdateServer.Assets

config :update_server, :viewport,
  name: :main_viewport,
  size: {884, 900},
  theme: :dark,
  default_scene: UpdateServer.UI.Scene.Home,
  drivers: [
    [
      module: Scenic.Driver.Local,
      name: :local,
      window: [resizeable: true, title: "Update Server"],
      on_close: :stop_system
    ]
  ]
