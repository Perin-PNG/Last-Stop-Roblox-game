# CLAUDE.md: Roblox game rules

You are building a Roblox game. You work in two places at once:
- **Files in this repo** (Luau code), synced into Studio by Rojo (`rojo serve`).
- **The open Roblox Studio place**, through the Roblox Studio MCP server (tools like
  `search_game_tree`, `inspect_instance`, `execute_luau`, `start_stop_play`,
  `get_console_output`, `screen_capture`, `insert_asset`, `save_place`).

## Who owns what
- **Code lives in files.** Everything under `src/` is owned by Rojo. Edit those `.luau` files on
  disk. Never edit a Rojo-managed script inside Studio (no `multi_edit` on `Shared`, `Server`
  or `Client`), because Rojo will overwrite it.
- **The world lives in the place.** Parts, models, maps, lighting, UI layouts built visually:
  make these in Studio with `execute_luau` (Edit datamodel) or `insert_asset`, then
  `save_place`. Describe what you built in `docs/world.md` so it isn't lost.
- If you make a one-off script in Studio to test something, delete it afterwards.

## Folder layout (see default.project.json)
| Folder | Ends up in Studio as | Runs on |
| --- | --- | --- |
| `src/server/` | ServerScriptService.Server | Server |
| `src/server/Services/` | one ModuleScript per system, `Init` then `Start` | Server |
| `src/client/` | StarterPlayer.StarterPlayerScripts.Client | Each player |
| `src/client/Controllers/` | one ModuleScript per system | Each player |
| `src/shared/` | ReplicatedStorage.Shared | Both |
| `Packages/` | ReplicatedStorage.Packages (Wally, don't edit) | Both |

New server system: add `src/server/Services/NameService.luau`. New client system: add
`src/client/Controllers/NameController.luau`. Remotes: add the name to `src/shared/Net.luau`.

## Luau rules
- Start every file with `--!strict`. Type function parameters and returns.
- Use `.luau` files. `X.server.luau` = Script, `X.client.luau` = LocalScript, anything else = ModuleScript.
- Use `game:GetService()`, never `game.Workspace` style lookups for services.
- Use `task.wait`, `task.spawn`, `task.delay`, `task.defer`. Never `wait`, `spawn`, `delay`.
- Use `WaitForChild` across the client/server boundary; don't assume replication has finished.
- Disconnect connections and `Destroy()` instances you create when they're done.
- No `while true do` loops without a `task.wait`. Prefer events and `RunService` signals.
- Put tunable numbers in `src/shared/Config.luau`.
- Log with `Log.info("Tag", ...)` from `Shared/Log` so messages are easy to find in the Output.

## Security
- The server is the authority. Never trust values from a client: check type, range and rate
  on every `OnServerEvent` / `OnServerInvoke`.
- Damage, currency, inventory and win conditions are decided on the server only.
- Never put secrets or admin checks in client or shared code.

## Data and money
- Use DataStoreService only in a server Service, with `pcall` and retries. Studio needs
  "Enable Studio Access to API Services" on to test it.
- Never set up Developer Products, Game Passes or anything that charges Robux without asking.
- Never publish the place, change its permissions or make it public. `save_place` only saves.

## How to work
1. Before changing code, read the related files. Before changing the world, use
   `search_game_tree` / `inspect_instance` to see what's there.
2. After editing code, run the checks: `selene src` and `stylua --check src`
   (or `scripts/check.ps1`). Fix every error.
3. Test in Studio: `start_stop_play` to start, wait a few seconds, `get_console_output`, use
   `screen_capture` to look, then stop the playtest. Fix errors you find and test again.
4. Keep changes small and commit after each working step with a clear message.
5. If Studio isn't connected (`list_roblox_studios` is empty), say so and keep to file work.

## This game
<!-- Fill this in per game: pitch, core loop, player count, art style, current milestone. -->
- Name:
- Pitch:
- Core loop:
- Current milestone:
