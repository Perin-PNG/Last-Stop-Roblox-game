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

## M2: the core game

- [ ] **Turn on API access now.** Home > Game Settings > Security > "Enable Studio Access to
      API Services". Without it, Tokens, Ranks, Perks, cosmetics and settings only last
      until you stop the test (the Collections tab says so in red). This needs the place
      saved to Roblox once (File > Save to Roblox); that doesn't publish it.
- [ ] **More sounds.** New keys in `src/shared/Config/Audio.luau`: Camera, Kiosk,
      StreetlightHum, plus the passenger and ride event ones (SoftSting, GlassSlap). Same as
      before: paste `"rbxassetid://..."` ids or send them to Claude.
- [ ] **The M2 playtest** (see `docs/M2-TEST.md`): a full run start to finish, then a
      second run to check that Tokens, Rank and what you bought were saved.
- [ ] **A 20-person playtest** when you can gather people (the M2 gate is a median session
      of 25 minutes or more). Friends, a Roblox group or a Discord. Note where people quit.

## M3: alpha features

- [ ] **The M3 playtest** (see `docs/M3-TEST.md`): the First Ride, then the full 11-stop
      route with the Terminal finale, solo and with friends.
- [ ] **Badges.** Creator Hub > your experience > Engagement > Badges. Make one for each
      key in `Badges` in `src/shared/Config/Products.luau` (FirstRide, Home, Transfer,
      LastStop, DriversSeat, BackFromTheBetween, EyesFront, NotOnMyBus, LateFee,
      Inspector, Lifer) and paste each id there, or send them to Claude. A badge with id 0
      is never awarded. The first few badges a day are free; Roblox shows the cost if not.
- [ ] **Game passes and products (when you decide to sell them).** Claude won't create
      anything that charges Robux. If you want them: Creator Hub > Monetization > Passes
      (CommuterPass, LiveryPack, VoicePackDispatch, PolaroidFrames) and Developer Products
      (Tokens500, Tokens1400, Tokens3000, RunDoubler, TipTheDriver). You set the prices.
      Paste the ids into `Products.luau`. Anything left at 0 stays hidden in the game.
- [ ] **Private servers (optional).** Game Settings > Monetization > Private Servers. A
      private server plays party runs (no strangers matched in).
- [ ] **Finale sounds.** New keys in `src/shared/Config/Audio.luau`: Horn, Breaker,
      PowerHum, GateOpen, Pry, Crash, EngineStart, Dawn, OtherBusDoors, WaterLap, Splash.
      The music group (MallMusic, Dawn) follows the Music volume slider.
- [ ] **Onboarding funnel.** After a few First Rides in a published test, open Creator
      Hub > Analytics > Onboarding funnel. The steps are Offered, Started, ReadRules,
      MetTheDriver, GasAndGo, PouredFuel, Laundromat, LoopCheck, Finished. A big drop
      between two steps tells Claude which tutorial step to fix.
- [ ] **Phone and gamepad.** Run the M3 playtest once on a phone (Studio's Device
      Emulator is fine for a first look) and once with a controller.

## M4: launch prep

- [ ] Everything in `docs/LAUNCH.md`: the questionnaire, the store page, the soft launch,
      creators and (if you choose) ads.
- [ ] **Share prompts:** in a published test on a phone, make it back from the Between or
      reach an ending. A small "Share" card should appear bottom right. Share prompts can
      be turned off in Settings.
