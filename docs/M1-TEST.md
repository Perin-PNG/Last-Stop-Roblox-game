# M1 playtest: the vertical slice

**Goal:** one complete run you can play start to finish: the depot, boarding, Gas & Go,
the Laundromat, the Diner, the Latecomer, Left Behind and The Between, the Clerk, the mirror
rule, pings, and the end screen.

Studio-only debug panel: **DBG** on the left edge (or F8). Buttons: seed and restart, skip,
god mode, teleport into the bus, start or end a run, fill fuel, bank a fragment, force an
anomaly (type its id in the box), spawn an entity (type `clerk`).

## 1. The depot (lobby)

1. Press Play. You start on the depot platform at night (third person).
2. Walk into the yellow **boarding bay**. The departures board and the top of the screen
   count down 20 seconds (3 seconds if everyone is in the bay).
3. At zero the screen fades and you wake up in a seat on the bus (first person).

Check: the board text updates; leaving the bay stops the countdown.

## 2. On the bus

- The Rules plaque is by the front door. Read it.
- Look at the wide mirror above the windshield for a few seconds: the Driver's face turns
  toward you and a hint appears. Keep staring past 3 seconds and the screen flashes red,
  and the Driver loses Patience (the light on his partition changes colour).
- Hold **Q** (PC), the **PING** button (phone) or **d-pad up** (gamepad), point at a sector
  and let go. Everyone sees the marker for 6 seconds with your name and the distance.

## 3. Gas & Go (stop 1)

- The bus pulls in. The stop name card shows. Get off through the middle door.
- The shelter timetable counts down to departure; the small "BUS LEAVES" timer at the top
  shows the same while you're off the bus (Settings will let you hide it).
- Grab a **fuel can** by the pumps and a **battery** from the store. Pour the fuel at the
  cap on the rear left corner (hold the prompt).
- Keys: **1-4** pick a slot, **left click** uses, **right click** throws, **G** drops, **F**
  flashlight, **Shift** sprint, **C** crouch.
- The departure bell rings; get back on before the doors close.

## 4. The Latecomer

At a later stop, the far bell rings and the streetlights start going out, far to near. A
tall figure in a long coat walks in along the sidewalk. Be on the bus before it reaches the
doors. **Pull the cord twice** to close the doors early. If someone holds the doors and it
gets aboard, the cabin lights go red and it downs a rider every 8 seconds until the next
stop.

## 5. Left Behind and The Between

Stay outside when the doors close. You're Left Behind: follow the trail markers through the
fog, step off the path when headlights sweep, and come out at the back of the next stop.
The payphones on the trail play a radio line if you hold the prompt.

## 6. Down and Static

Get caught (the Clerk at a Gas & Go loop check, a dryer, the Latecomer). You're **Down**: a
red screen and a bleed-out timer. A teammate can carry you (prompt on you) to the bus;
lie in the recovery bay at the back to get up. Bleed out and you're **Static**: the camera
follows a living teammate (arrows or 1-4 to switch), and you can still ping.

## 7. Loop check

Gas & Go comes back. If anything changed (the clerk faces the wall, an extra car, the
prices), **stay on the bus and pull the cord twice**. "Good call, Unit 9." Getting off
when it changed wakes the Clerk.

## 8. The end

The run ends when everyone is Static, or at the Terminal. The end screen shows the ending,
stops survived and fragments. After about 25 seconds you're back at the depot.

## What to report back

- Anything that errors in the Output (filter by `[Run]`, `[Stops]`, `[Entity]`, `[Input]`).
- Whether the phone buttons are reachable with your thumbs.
- Whether the mirror face is creepy enough, and readable on a phone.
- Whether 20 seconds in the lobby bay feels too long.
