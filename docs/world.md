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
| Tier 1 and 2 stops | `Builders/Stops/library.luau`, `willow_court.luau`, `mercy_general.luau`, `motel.luau`, `rest_area.luau`, `mall.luau`, `depot.luau`, `farm_stand.luau` | Workspace.Stops | Shared furniture comes from `Builders/Props.luau` (shelves, tables, chairs, counters, beds, lockers, swinging doors, windows, fences, trees, parked cars). Each stop builds its own threat's terrain: the library stacks, the Willow Court houses that shelter you, the hospital breaker and pharmacy, the motel doors that knock, the rest area lot loop Headlights drives, the mall concourse, the depot bus bays, and a fresh corn maze each night |
| The Between | `Services/BetweenService.luau` | Workspace.Between | One fogged footpath per stop, far from the route: trail lights, trees, payphones, an exit lamp |
| Entities | `Services/EntityService.luau`, `LatecomerService.luau` | Workspace.Entities | Built from parts at runtime (the Clerk, the Latecomer) |
| Passengers and mimics | `Builders/PassengerRig.luau`, `Services/PassengerService.luau` | Workspace.Passengers, then seated in Workspace.Bus.Bus | Waiting riders stand at the curb; boarded ones sit welded to their seat. A revealed mimic stands tall in the aisle |
| Ride events | `Services/RideEventService.luau` | Workspace.Bus.Bus | The Fare Inspector walking the aisle, the KnockFace on the rear window |
| The rider kiosk | `Services/KioskService.luau` | Workspace.Lobby.Kiosk | A blue HCTA kiosk on the depot platform, near the spawn. Its prompt opens the menu's Kiosk tab |
| Worn cosmetics | `Services/CosmeticService.luau` | Inside each character (CosmeticJacket, CosmeticHat) and Workspace.Bus.Bus.SeatCharm | Jackets, caps and pins are welded shells over the avatar. Seat charms hang off the seat you sit in |

## Swapping in real art later

Builders look in **ServerStorage.Assets** first:

- `ServerStorage.Assets.Stops.<stop id>`: a Model whose pivot is the curb point. It is
  placed on top of the blockout.
- `ServerStorage.Assets.Bus`: reserved for a custom bus model (keep the part names the
  builder uses).
