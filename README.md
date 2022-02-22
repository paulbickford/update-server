# UpdateServer

A tool to send a command to multiple servers using SSH connections.

## Requirements

Linux.

Each server must be configured with an SSH key pair in order to login without a password.

## Installation

Clone repo.

This bakeware project compiles into single executable. It uses the Mix releases process to build binaries and place then into `_build/prod/rel/bakeware/my_script`

1. Install `zstd` to enable compression during assembly.
2. Build with `MIX_ENV=prod`, so dev dependencies are not included in binary.
3. Clean build directory.
4. Build release.

```
$ export MIX_ENV=prod
$ rm -fr \_build
$ mix deps.get
$ mix release
```

Binary will be in `_build/prod/rel/bakeware/my_script`.

In `mix.exs`, the binary wil be copied to the linux system path. You may need to change this location.

```
defp release do
  [
    ...
    steps: [:assemble, &Bakeware.assemble/1, &copy_to_system/1],
    ...
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
```

## Usage

When started on the command line, the application will create a window and read a list of servers from the disk. A connection to each server will be attempted and a command, if given, will be sent to each. The commands and
responses will be shown in each server's section of the window.

```
$ update-server <cmd>
```

Each connected server will be listed with an associated ordinal number
(essentially a shortcut) to allow easier command line input. These numbers
are associated to the server at runtime and no not persist between sessions.

Subsequent commands given in the console will be sent to all servers unless preceded by `-s <server_number>`, in which case the command will be sent only
to the given server.

### Switches

<dl>
<dt>-a [--add] name</dt>
<dd>Add server, or list of servers separated by spaces and enclosed in quotes, to default servers list and connect to server.</dd>
<dt>-c [--close] server_number</dt>
<dd>Close connection to server.</dd>
<dt>-d [--delete] name</dt>
<dd>Delete server from file. Does not close connection, if connected.</dd>
<dt>-h [--help]</dt>
<dd>Help</dd>
<dt>-l [--list]</dt>
<dd>List connected servers with codes.</dd>
<dt>-o [--open] name </dt>
<dd>Open connection to server, server_number, or list of servers separated by spaces and enclosed in quotes, but do not add to default servers list.</dd>
<dt>-p [--persisted]</dt>
<dd>List persisted (default) servers.</dd>
<dt>-q [--quit]</dt>
<dd>Quit application.</dd>
<dt>-s [--server] server_number</dt>
<dd>Server_number to send command to.</dd>
</dl>
