# World notes

The world is built by server scripts when the game starts, so it lives in git and nothing
needs to be saved in the place file. Builders live in `src/server/Builders/`.

| What | Built by | Where in Explorer | Notes |
| --- | --- | --- | --- |
| The bus (HCTA Unit 9) | `Builders/BusBuilder.luau` | Workspace.Bus.Bus | 56 x 12 x 13 studs, 1.3x scale. Unanchored and driven by AlignPosition/AlignOrientation in Physics mode. Persistent for streaming |
| Road chunks | `Builders/RoadBuilder.luau`, `Services/ChunkService.luau` | Workspace.Road | Straight, curve, hill, bridge, tunnel, overpass, stop, terminal. About three ahead of the bus, deleted behind |
| Stops | `Builders/Stops/<id>.luau` using `Builders/StopKit.luau` | Workspace.Stops | One model per stop, Atomic for streaming. Origin is the curb point |
| Lighting | `Services/WorldService.luau` | Lighting | Night, fog through Atmosphere, a colour grade, bloom, a starfield sky. Set Technology to Future by hand |
| The depot (lobby) | `Services/LobbyService.luau` | Workspace.Lobby.Depot | Platform, canopy, boarding bay, departures board, title sign, benches, LobbySpawn |
| Gas & Go, Laundromat, Diner | `Builders/Stops/gas_and_go.luau`, `laundromat.luau`, `diner.luau` | Workspace.Stops | Each has a shelter with a live timetable, lit ad panel, streetlights, loot points, anomaly slots and a back entrance for The Between |
| The Between | `Services/BetweenService.luau` | Workspace.Between | One fogged footpath per stop, far from the route: trail lights, trees, payphones, an exit lamp |
| Entities | `Services/EntityService.luau`, `LatecomerService.luau` | Workspace.Entities | Built from parts at runtime (the Clerk, the Latecomer) |

## Swapping in real art later

Builders look in **ServerStorage.Assets** first:

- `ServerStorage.Assets.Stops.<stop id>`: a Model whose pivot is the curb point. It is
  placed on top of the blockout.
- `ServerStorage.Assets.Bus`: reserved for a custom bus model (keep the part names the
  builder uses).
