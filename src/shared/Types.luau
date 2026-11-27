--!strict
-- Shared type names. Run state lives as attributes on ReplicatedStorage.RunState and per
-- player state as attributes on each Player; these are the names and their values.

export type PlayerState = "Lobby" | "Aboard" | "Outside" | "Downed" | "LeftBehind" | "Static" | "Spectating"

export type Phase =
	"Idle" -- no run (lobby only)
	| "Boarding" -- everyone is getting on at the first stop
	| "Ride" -- the bus is driving between stops
	| "Arriving" -- pulling in to the curb
	| "Stop" -- doors open, the departure timer runs
	| "Departing" -- doors closing, pulling away
	| "Stalled" -- out of fuel at a stop
	| "Finale" -- the Terminal
	| "Ending" -- end screen

export type Tier = number

-- RunState attribute names (all replicate to every client).
local RunAttr = {
	Phase = "Phase", -- Phase
	Seed = "Seed", -- number
	Tier = "Tier", -- 1..3 (4 at the Terminal)
	StopIndex = "StopIndex", -- 1..12, overtime continues counting
	StopId = "StopId", -- current or next stop id
	StopName = "StopName",
	NextStopName = "NextStopName",
	Deadline = "Deadline", -- GetServerTimeNow() when the doors close
	Fuel = "Fuel", -- tank bars
	Patience = "Patience", -- 0..100
	Fragments = "Fragments", -- banked fragments
	Overtime = "Overtime", -- lap number, 0 when not in overtime
	BusMode = "BusMode", -- "Physics" | "Stationary"
	DoorsOpen = "DoorsOpen",
	VoteOpen = "VoteOpen",
	VoteA = "VoteA", -- stop ids on the ballot
	VoteB = "VoteB",
	VoteCountA = "VoteCountA",
	VoteCountB = "VoteCountB",
	VoteDeadline = "VoteDeadline",
	Rules = "Rules", -- comma-separated rule ids on the plaque
	Mode = "Mode", -- "Standard" | "Tutorial" | "Daily" | "Graveyard"
	Blackout = "Blackout",
	LatecomerActive = "LatecomerActive",
	Clock = "Clock", -- in-fiction time text
	Passengers = "Passengers", -- count aboard
	Holding = "Holding", -- someone holds the Hold button
	CordPulls = "CordPulls",
}

local PlayerAttr = {
	State = "State",
	Dread = "Dread",
	Stamina = "Stamina",
	Ticket = "Ticket", -- boolean
	Transfers = "Transfers",
	Slot = "Slot", -- selected inventory slot
	Inventory = "Inventory", -- comma-separated item ids by slot ("" for empty)
	Battery = "Battery",
	Film = "Film",
	BleedDeadline = "BleedDeadline",
	CarriedBy = "CarriedBy",
	Carrying = "Carrying",
	Stance = "Stance",
	Rank = "Rank",
	Tokens = "Tokens",
	Perks = "Perks",
	Livery = "Livery",
	Party = "Party",
	Calm = "Calm", -- Calm Mode setting
	Muffled = "Muffled",
	Gaze = "Gaze", -- seconds of mirror gaze, 0..3
	Flicker = "Flicker", -- flashlight is flickering (counts as looking away)
	Light = "Light", -- flashlight on
	Recovering = "Recovering", -- GetServerTimeNow() when the Recovery bay stands them up
}

return {
	RunAttr = RunAttr,
	PlayerAttr = PlayerAttr,
}
