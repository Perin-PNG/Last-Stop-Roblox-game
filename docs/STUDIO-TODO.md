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
