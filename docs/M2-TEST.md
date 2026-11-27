# M2 playtest: the core game

**Goal:** a full run plays start to finish with no blocking bugs, and the game around it
(Tokens, Ranks, Perks, the kiosk, saved settings) survives leaving and rejoining.

Before you start: turn on **Enable Studio Access to API Services** (see STUDIO-TODO), or
saving is skipped for the session. The debug panel (**DBG** or F8) now has **+500 Tokens
(and XP)** for testing the kiosk and Perks quickly.

## 1. The depot

1. Press Play. Top right there's a **MENU** button (or press **M**, or Select on a gamepad).
2. Walk to the blue **HCTA Rider Kiosk** near the spawn and open it.
3. **Kiosk tab:** with 0 Tokens everything reads "need N more". Press **+500 Tokens** in the
   debug panel, then buy the **Warm Beam** and the **Night Owl Cap**.
   Check: the Tokens counter drops, the cap appears on your head, and your own hats hide.
4. **Perks tab:** +500 Tokens is also 500 XP, which is Rank 5, so Light Sleeper is unlocked.
   Equip it. Press +500 four more times to reach Rank 16 and check that a second slot opens.
5. **Settings tab:** turn on Dread meter and Reduce flashing, set volume to 50%.

## 2. A full run

Play a normal run to the end. Things to watch for that are new in M2:

- **Passengers** wait at some curbs. Ask for their ticket, tell one to wait, let others
  board. Watch for the tells: a passenger who never blinks, has no reflection in the
  window, knows your name, holds a ticket dated tomorrow, or casts a shadow the wrong way.
- **Escort off** a suspected mimic while the doors are open (hold F for 3 seconds). A
  mimic shows its true shape and chases you. A regular just walks away, and the Driver
  minds.
- **The Polaroid**: photograph an anomaly for Evidence (+2 transfers once each), and a
  passenger for a portrait. A mimic's face can come out smeared.
- **Ride events** between stops: a Blackout (stay seated), knocking on the rear window
  (don't look back, don't open it), the Fare Inspector (keep your ticket; hold G on a teammate
  with no ticket to hand them yours).
- **Fake Rules** from Tier 2: a sticker in different handwriting. "Open the rear window"
  and "Give your ticket to anyone who asks" are traps.
- **Rosie's Diner** sells the Return Ticket (15 transfers, once a run) that brings one
  Static teammate back.
- **Static** (Lost) players get Flicker, the four radio words and Reveal on the spectate
  bar, once per stop.
- **Sound**: with sounds in place, the street goes muffled when the doors shut and you're
  in your seat. With no ids yet, the captions should still appear.

At the end screen: the **Token payout** lists stops, photos, fragments and the ending, the
first-run-of-the-day double, and a Rank bar that fills.

## 3. Rejoin

Stop the test and press Play again. Check that your Tokens, Rank, the cap, the Perk and
your settings are all as you left them.

## Tell Claude

- Anything that stopped the run (errors in Output with a red line).
- Anything confusing: a prompt you didn't understand, a Rule you couldn't follow.
- How long a full run took.
