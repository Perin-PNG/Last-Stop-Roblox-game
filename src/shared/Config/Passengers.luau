--!strict
-- Passengers are data: an outfit from a curated pool (no real brands), bubble lines,
-- a gift table and how many stops they ride.

export type PassengerDef = {
	id: string,
	name: string,
	recurring: boolean,
	skin: Color3,
	shirt: Color3,
	pants: Color3,
	hat: Color3?,
	prop: string?, -- "birdcage", "box", "headphones", "uniform"
	lines: { string },
	gifts: { [string]: number }, -- item id or "hint" or "transfers" -> weight
	minTier: number?,
	clue: string?,
}

local Regulars: { PassengerDef } = {
	{
		id = "dolores",
		name = "Dolores",
		recurring = true,
		skin = Color3.fromRGB(160, 110, 80),
		shirt = Color3.fromRGB(110, 170, 170),
		pants = Color3.fromRGB(110, 170, 170),
		prop = "badge",
		lines = {
			"Night shift. Always the night shift.",
			"If you end up at Mercy General, stay out of the east wing.",
			"Here. You look like you'll need this more than me.",
			"Don't let them hear you in the ER. It can't see, but it listens.",
			"I've ridden this bus a thousand times. It's never been this late.",
			"Keep your ticket where you can feel it.",
		},
		gifts = { medkit = 5, hint = 2 },
	},
	{
		id = "abernathy",
		name = "Mr. Abernathy",
		recurring = true,
		skin = Color3.fromRGB(225, 190, 160),
		shirt = Color3.fromRGB(90, 70, 50),
		pants = Color3.fromRGB(60, 55, 50),
		hat = Color3.fromRGB(50, 40, 30),
		prop = "birdcage",
		lines = {
			"I've been on this route since 1987.",
			"She doesn't like the tunnels. Do you, dear?",
			"The driver used to wave. Back when he had a face.",
			"Count the pumps when you stop at the station. Always count the pumps.",
			"Don't uncover the cage. She's sleeping.",
			"The next stop always looks like the last one. Until it doesn't.",
		},
		gifts = { hint = 4, transfers = 2, flare = 1 },
	},
	{
		id = "sleeper",
		name = "The Sleeper",
		recurring = true,
		skin = Color3.fromRGB(200, 150, 110),
		shirt = Color3.fromRGB(70, 60, 100),
		pants = Color3.fromRGB(40, 40, 50),
		prop = "headphones",
		lines = {
			"...",
			"...mm. Not my stop.",
			"...the true channel is on two-two-seven...",
			"...",
		},
		gifts = { headphones = 3, hint = 1 },
	},
	{
		id = "courier",
		name = "The Courier",
		recurring = true,
		skin = Color3.fromRGB(110, 80, 60),
		shirt = Color3.fromRGB(150, 110, 60),
		pants = Color3.fromRGB(50, 50, 60),
		hat = Color3.fromRGB(150, 110, 60),
		prop = "box",
		lines = {
			"Package for %s. Signature not required.",
			"I don't deliver to addresses. I deliver to people.",
			"Route 9N, final destination. That's what the label says.",
			"Don't shake it.",
		},
		gifts = { flare = 2, polaroid = 2, battery = 2, radio = 1 },
	},
	{
		id = "off_duty",
		name = "The Off-Duty Driver",
		recurring = true,
		skin = Color3.fromRGB(210, 170, 140),
		shirt = Color3.fromRGB(40, 60, 90),
		pants = Color3.fromRGB(30, 35, 45),
		hat = Color3.fromRGB(40, 60, 90),
		prop = "uniform",
		lines = {
			"I drove the 9N once. One night. That was enough.",
			"Don't look at him. He remembers faces.",
			"His locker's at the depot. Number nine.",
			"The Terminal is where he gets off. Someone has to take the wheel.",
		},
		gifts = { hint = 3, transfers = 2 },
		clue = "off_duty",
	},
	{
		id = "commuter",
		name = "Commuter",
		recurring = false,
		skin = Color3.fromRGB(235, 200, 170),
		shirt = Color3.fromRGB(120, 120, 130),
		pants = Color3.fromRGB(40, 40, 45),
		lines = {
			"Long night?",
			"I just want to get home.",
			"Is this the 9N? It doesn't feel like the 9N.",
			"I missed my stop three stops ago. I think.",
		},
		gifts = { battery = 3, transfers = 3, coffee = 2, hint = 2 },
	},
	{
		id = "student",
		name = "Student",
		recurring = false,
		skin = Color3.fromRGB(180, 130, 95),
		shirt = Color3.fromRGB(150, 60, 60),
		pants = Color3.fromRGB(50, 60, 90),
		lines = {
			"Exam at eight. Great.",
			"My phone has no signal out here. Does yours?",
			"I saw something at the last stop. Never mind.",
		},
		gifts = { food = 3, battery = 2, hint = 2 },
	},
	{
		id = "fisherman",
		name = "Fisherman",
		recurring = false,
		skin = Color3.fromRGB(200, 160, 130),
		shirt = Color3.fromRGB(70, 90, 60),
		pants = Color3.fromRGB(60, 60, 50),
		hat = Color3.fromRGB(70, 90, 60),
		lines = {
			"Water's high tonight.",
			"Low Water Station used to be dry, you know.",
			"Don't stand still near the water.",
		},
		gifts = { flare = 2, hint = 3, bottle = 1 },
		minTier = 2,
	},
}

-- Mimics borrow a regular's look. Their bubble lines are close but wrong.
local MimicLines = {
	"Long night, %s?",
	"I just want to get home with you.",
	"Don't mind me. I'm a regular.",
	"Is this your stop? It's my stop too.",
	"Sit with me in the back.",
}

-- The eight mimic tells. Every mimic carries two at random.
local Tells = {
	"no_reflection",
	"photo_blurred",
	"ticket_tomorrow",
	"never_blinks",
	"echoes_ping",
	"knows_name",
	"wrong_shadow",
	"false_hint",
}

return {
	Regulars = Regulars,
	MimicLines = MimicLines,
	Tells = Tells,
	ShareByTier = {
		{ regular = 0.85, mimic = 0.15 },
		{ regular = 0.65, mimic = 0.35 },
		{ regular = 0.5, mimic = 0.5 },
	},
}
