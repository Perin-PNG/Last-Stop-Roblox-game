--!strict
-- Player-facing text that isn't item or stop data: pings, hints, PA lines, radio.

local Pings = {
	{ id = 1, text = "Wait!", icon = "\u{270B}", shape = "circle" },
	{ id = 2, text = "Close the doors!", icon = "\u{1F6AA}", shape = "square" },
	{ id = 3, text = "Anomaly here", icon = "!", shape = "triangle" },
	{ id = 4, text = "Mimic?", icon = "?", shape = "diamond" },
	{ id = 5, text = "Help me", icon = "+", shape = "cross" },
	{ id = 6, text = "Loot here", icon = "$", shape = "hex" },
	{ id = 7, text = "Follow me", icon = "\u{2192}", shape = "arrow" },
	{ id = 8, text = "Yes / No", icon = "\u{00B1}", shape = "split" },
}

-- One-time hints, shown the first time each thing happens.
local Hints = {
	read_rules = "Read the Rules plaque by the front door.",
	dont_watch = "Don't watch the Driver.",
	teammate_down = "A teammate is Down. Carry them to the bus.",
	first_passenger = "A passenger is waiting. Ask for their ticket, or tell them to wait for the next bus.",
	left_behind = "You were left behind. Follow the trail markers.",
	lost = "You are Static. Help from the other side.",
	cord = "Pull the cord twice to close the doors and leave.",
	fuel = "Pour fuel at the cap on the rear left corner of the bus.",
	fragment = "Place map fragments on the route board to bank them.",
	vote = "Vote for the next stop on the route board.",
	latecomer = "The streetlights are going out. Something is coming. Get aboard.",
	hold = "The Hold button keeps the doors open, but the Driver loses patience.",
	dread = "Stay near teammates and light to keep calm.",
	ping = "Hold Q (or the ping button) to ping.",
	stalled = "The tank is empty. Someone has to pour fuel before the bus can leave.",
	loop_check = "Gas & Go again. If anything changed, stay on the bus and pull the cord twice.",
}

local PA = {
	nextStop = "Next stop: %s.",
	arriving = "%s.",
	departingSoon = "Doors closing in %d seconds.",
	doorsClosing = "Doors closing.",
	stalled = "Out of fuel. This bus will not depart until it is refueled.",
	patienceZero = "Last stop for you.",
	terminal = "Terminal. All passengers must disembark.",
	goodCall = "Good call, Unit 9.",
	offRoute = "Unit 9, you are off route.",
	inspection = "Fare inspection. Please have your tickets ready.",
	blackout = "Tunnel ahead.",
	confirmCount = "Unit 9N, confirm passenger count.",
	tutorialEnd = "End of the line, for now.",
	lastStopBoard = "LAST STOP",
}

-- Dispatch radio chatter, played on rides. Some lines are hints.
local Radio = {
	"Unit 9N, confirm passenger count.",
	"All units, fog advisory on the county road.",
	"Unit 9, you are running late. You are always running late.",
	"Copy, Unit 9. Keep the doors closed after the bell.",
	"Unit 9, dispatch has no record of your route.",
	"Reminder to all drivers: do not acknowledge riders who have missed the bus.",
	"Unit 9, the Terminal is expecting you.",
	"All units, Low Water Station is closed due to high water. It is always closed.",
}

local TrueChannel = {
	"...this is the true channel. Unit 9 has no driver. Unit 9 has never had a driver...",
	"...whoever sits up front at the end, the bus will listen to them...",
	"...five pieces of the route. Put them on the board. It's the only way out...",
}

-- End-of-run titles, by ending id.
local Endings = {
	LastStop = { title = "LAST STOP", line = "The bus went on without you." },
	Transfer = { title = "TRANSFER", line = "You got off at the Terminal. The bus left for its next route." },
	Home = { title = "HOME", line = "You drove Unit 9 out of Hollow County. The sun came up." },
	Secret = { title = "THE DRIVER", line = "The face in the mirror is yours now." },
	Tutorial = { title = "END OF THE LINE, FOR NOW", line = "First Ride complete." },
	Abandoned = { title = "OUT OF SERVICE", line = "Everyone left the bus." },
}

-- What a teammate portrait says for each player state.
local States = {
	Aboard = "On the bus",
	Outside = "Off the bus",
	Downed = "Down",
	LeftBehind = "Left behind",
	Static = "Static",
	Lobby = "At the depot",
}

return {
	Endings = Endings,
	States = States,
	Pings = Pings,
	Hints = Hints,
	PA = PA,
	Radio = Radio,
	TrueChannel = TrueChannel,
}
