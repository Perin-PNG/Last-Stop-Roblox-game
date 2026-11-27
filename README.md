# Roblox starter (Claude Code + Studio MCP + Rojo)

A template for building a Roblox game with Claude Code. Code lives in `src/` and syncs into
Studio through Rojo. Claude edits the code files and also works in the open Studio place
through Studio's built-in MCP server. Full guide: the "Claude Roblox game maker setup" doc.

## Quick setup (Windows)
From inside this folder, in PowerShell:
```
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -ProjectName last-stop -RemoteUrl https://github.com/YOUR-NAME/YOUR-REPO.git
```
It installs Git, Claude Code and Rokit if missing, copies this template to `~\RobloxGames\last-stop`,
installs the pinned tools and the Rojo plugin, builds the place file and sets up git.

## First time on a new game (by hand)
```
# copy this folder, rename it, then inside it:
git init
rokit install
wally install
rojo plugin install
rojo build -o MyGame.rbxl
```
Open `MyGame.rbxl` in Studio, then run `rojo serve` and click Connect in the Rojo plugin.

## Connect Claude
1. Studio: Assistant > ... > Manage MCP Servers > turn on "Enable Studio as MCP server".
2. Assistant Settings > MCP Servers > Quick connect > turn on Claude Code.
3. Restart Studio and run `claude` in this folder. Check with: "list the Roblox Studios you can see".

If Quick connect doesn't work, add it by hand (Windows):
```
claude mcp add --scope user Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
```

## Every session
```
rojo serve      # terminal 1
claude          # terminal 2
```
Slash commands: `/playtest`, `/check`, `/build <what to build>`.

## Layout
- `src/server/` > ServerScriptService.Server (Services/ = one module per system)
- `src/client/` > StarterPlayer.StarterPlayerScripts.Client (Controllers/)
- `src/shared/` > ReplicatedStorage.Shared (Config, Net, Log)
- `Packages/` > ReplicatedStorage.Packages (Wally)
- `docs/world.md` notes what was built in the place itself
