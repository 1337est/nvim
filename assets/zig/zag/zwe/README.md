# Zig Workspace Engine

This project should be the backbone to editing text and debugging my zig projects. It should understand where all my projects are, performantly and gradually replace LSP functionality with custom BSP/CSP logic, and stay up to date with the latest stable zig version. At some point this could hopefully be the backend for a text editor.

## cli commands

No other options other than the ones specified here are supported

`zwe` or `zwe --help`: print usage
`zwe --version`: zwe, zig, and protocol versions

`zwe nvim --print-file=client`
`zwe nvim --print-file=lsp`

`zwe config --print-file=template`
`zwe config`
`zwe config --file=FILE`
`zwe config --resolve=PATH`
`zwe config --file=FILE --resolve=PATH`
`zwe config --resolve=PATH --snapshot`

`zwe manifests [ABS_MANIFEST ...]`: process one or more build.zig.zon files and print dependency metadata as JSON. Without arguments, accepts a JSON array of absolute manifest paths through stdin.

`zwe serve --socket=ABS_PATH --root=ABS_ROOT [--zig=ZIG] [--build-option=NAME=VALUE]...`: start a ZWE daemon for a workspace.
`--socket=ABS_PATH`: required absolute Unix socket path for communication with the daemon.
`--root=ABS_ROOT`: required absolute workspace root.
`--zig=ZIG`: optional Zig compiler executable, defaults to `zig`.
`--build-option=NAME=VALUE`: optional, repeatable Zig build option without the `-D` prefix.

## nvim config commands

### Workspace and configuration

`:ZweWorkspace [NAME]`: display the current workspace or a specified workspace.
`:ZweConfigReload`: validate and reload config.zon, preserving the previous configuration if validation fails.
`:ZweWorkspaceRefresh`: refresh workspace configuration and contexts.
`:ZweToolchain ZIG [ZLS]`: override the Zig compiler and optionally ZLS executable for the current workspace session.
`:ZweBuildOptions [OPTION ...]`: set workspace build options without the `-D` prefix. No arguments clears the overrides.
`:ZweTrust`: trust the current workspace for automatic build graph configuration.
`:ZweTrust!`: revoke workspace trust for the current session.

### Code intelligence and daemon control

`:ZweDefinition`: navigate to the definition of the symbol under the cursor.
`:ZweComplete`: request code completion at the cursor.
`:ZweSymbols`: display symbols in the current Zig document.
`:ZweFormat`: format the current Zig document.
`:ZweStatus`: display current workspace daemon status, statistics, and BSP information.
`:ZweRefresh`: refresh the current workspace build graph.
`:ZweStop`: stop the current workspace's ZWE daemon.
`:ZweStop!`: stop all active ZWE daemons.
`:ZweRestart`: restart the current workspace's ZWE daemon.
`:ZweRestart!`: restart all active ZWE daemons.

### Building and execution

`:ZweBuild [STEP_OR_ARG ...]`: build the current workspace using its configured Zig compiler. Arguments are forwarded to Zig. Standalone Zig files default to `build-exe` and support `test`, `run`, `build-lib`, `build-obj`, and `build-exe`.
`:ZweBatch [WORKSPACE ...] [-- STEP_OR_ARG ...]`: preview builds for all or specified registered workspaces. Use `--` to separate workspace names from Zig build arguments.
`:ZweBatch! [WORKSPACE ...] [-- STEP_OR_ARG ...]`: execute the selected workspace builds concurrently.
`:Zig [ARG ...]`: execute a Zig command in the current file's directory. No arguments displays the Zig compiler version and executable path.
`:ZigExe [PATH]`: override the Zig executable used by raw `:Zig` commands. No arguments clears the override.
`:ZigWindow`: open, focus, or hide Zig build output.
`:ZigStop`: interrupt a running Zig build, or select which build to stop when multiple jobs are active.

### Manifest inspection

`:ZweManifests [PATH ...]`: inspect build.zig.zon dependency metadata without executing build scripts. Defaults to the current workspace's build.zig.zon.
