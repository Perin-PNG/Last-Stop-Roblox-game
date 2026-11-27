# M0 gate test: walking inside the moving bus

**Gate:** four players walk around inside the moving bus for five minutes, on PC and on a
phone, with no falling through, sliding or jitter that testers notice.

## What you'll see

Press Play. You spawn inside HCTA Unit 9 on a night road. The bus drives a road that is
generated ahead of it (straights, wide curves, hills, bridges, tunnels, overpasses), pulls
in at a plain stop with a shelter and a small shop, opens its doors for 40 seconds, closes
them and drives on. Forever, for now.

Studio-only debug panel: click **DBG** on the left edge (or press F8). Buttons: set seed and
restart, skip the stop or ride, god mode, teleport into the bus.

## Test 1: Studio, four clients

1. Test tab > Clients and Servers > Local Server, **4** players, Start.
2. In each client window, walk up and down the aisle, jump, sit in seats and stand up,
   stand at the back bench, stand by the doors during curves and while braking.
3. Get off at a stop and get back on before the doors close.
4. Five minutes. Note any sliding, rubber-banding, falling through the floor or getting
   flung.

## Test 2: latency

1. File > Studio Settings > Network > **Incoming Replication Lag** = 0.2 (200 ms).
2. Repeat test 1.

## Test 3: with and without Server Authority

Server Authority needs StreamingEnabled (already on) and Workspace > AuthorityMode =
**Server**. Run tests 1 and 2 with AuthorityMode on Automatic, then on Server. Keep
whichever feels smoother and tell Claude.

## Test 4: a real phone

Publish to a private test (File > Publish to Roblox, keep it private), join on your phone
with a friend or an alt on PC. Walk around for five minutes.

## If it fails

Open `src/shared/Config/Tuning.luau` and change `Tuning.Bus.Mode = "Physics"` to
`"Stationary"`. The bus then stays still while the road scrolls past the windows, and each
stop appears beside it after a short fade. Things to try first, in Tuning.Bus:

- `AlignResponsiveness` (60): higher is stiffer.
- `AlignRigid` (false): true makes the bus follow its target exactly.
- `CruiseSpeed` (58): the plan allows 50 to 70.

## What to send Claude

Which mode felt better, whether Server Authority helped, the worst moment (where in the bus,
what the bus was doing) and anything in the Output window that starts with `[Bus]`,
`[Chunks]` or `[Run]`.
