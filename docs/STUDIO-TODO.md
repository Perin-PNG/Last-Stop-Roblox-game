# Studio to-do (only Perin can do these)

Claude builds everything in code. These steps need Roblox Studio, Creator Hub or a real
device. Tick them off as you go. Newest milestone at the bottom.

## M0: foundations and the bus spike

- [ ] **Pull and open.** Your auto-pull loop picks up `main`. In Studio, make sure the Rojo
      plugin is connected (`rojo serve` running). The old TestBlock is gone; the world is now
      built by scripts when you press Play.
- [ ] **Turn on API access (for later).** Home > Game Settings > Security > "Enable Studio
      Access to API Services". Needed from M2 for saving.
- [ ] **Avatar type R15.** Game Settings > Avatar > Avatar type: R15.
- [ ] **Streaming.** `default.project.json` turns on `Workspace.StreamingEnabled` (min radius
      128, target 768). Check it shows as on in Workspace's properties after Rojo syncs.
- [ ] **The M0 gate test** (see `docs/M0-TEST.md`): four players walking inside the moving
      bus for five minutes, on PC and a phone, at 200 ms simulated latency, with and without
      Server Authority.
- [ ] **Pick the bus mode.** If the moving bus feels bad, set `Tuning.Bus.Mode = "Stationary"`
      in `src/shared/Config/Tuning.luau` (or tell Claude) and test again.
- [ ] **Create the experience and the two places** when you're ready to publish tests:
      Creator Hub > Create > new experience. The start place is the Lobby. Add a second
      place (Asset Manager > Places > Add new place) for the Route. Paste both PlaceIds into
      `src/shared/Config/Products.luau` (`Places.Lobby`, `Places.Route`), or send them to
      Claude. Until then the game runs lobby and run in one server, which is what you want
      in Studio.

## M1: the vertical slice

- [ ] **Lighting technology.** Select Lighting and set **Technology** to **Future** (scripts
      can't set it). Neon tubes, lamps and the lit shelter ads look much better with it.
- [ ] **Sounds.** Every sound key is listed in `src/shared/Config/Audio.luau` with an empty
      id. Pick licensed sounds in the Creator Store (Toolbox > Audio) or upload your own,
      and paste each id as `"rbxassetid://123"`, or send the ids to Claude. Until then the
      game shows a caption for every sound instead. The ones that matter most for M1:
      DieselHum, DoorHiss, DepartureBell, CordDing, PAChime, FarBell, LightPop, Knock,
      DryerThump, DryerBurst, EntitySpotted, Caught, LatecomerBoard, RadioStatic, Heartbeat,
      PingBlip, Sting.
- [ ] **Voice as noise (optional).** Game Settings > Communication: turn on voice chat and
      "Use audio API" if you want spoken noise to attract entities. It works without.
- [ ] **The M1 playtest** (see `docs/M1-TEST.md`): a full run of the slice, solo and with
      friends, on PC and on a phone.
