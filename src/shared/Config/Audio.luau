--!strict
-- Sound ids. All are empty until Perin picks licensed sounds from the Creator Store
-- (or uploads their own recordings) and pastes the ids here as "rbxassetid://123".
-- Empty ids are skipped silently; every telegraph still shows its caption.

export type SoundDef = { id: string, volume: number, looped: boolean?, caption: string? }

local S: { [string]: SoundDef } = {
	-- Bus
	DieselHum = { id = "", volume = 0.5, looped = true },
	DoorHiss = { id = "", volume = 0.8, caption = "Doors hiss" },
	DoorChimeBus = { id = "", volume = 0.6 },
	DepartureBell = { id = "", volume = 0.8, caption = "Departure bell" },
	CordDing = { id = "", volume = 0.7, caption = "Ding" },
	PAChime = { id = "", volume = 0.6 },
	RadioStatic = { id = "", volume = 0.4, looped = true },
	Rain = { id = "", volume = 0.4, looped = true },
	Knock = { id = "", volume = 0.9, caption = "Knocking on the rear window" },
	FluorBuzz = { id = "", volume = 0.2, looped = true },
	StreetlightHum = { id = "", volume = 0.15, looped = true },
	PourFuel = { id = "", volume = 0.6, caption = "Fuel pouring" },
	Heartbeat = { id = "", volume = 0.6, looped = true },
	Breath = { id = "", volume = 0.4, looped = true },
	Sting = { id = "", volume = 1, caption = "!" },
	SoftSting = { id = "", volume = 0.5 },
	Static = { id = "", volume = 0.6 },
	Camera = { id = "", volume = 0.8, caption = "Camera shutter" },
	Kiosk = { id = "", volume = 0.5, caption = "Kiosk chimes" },
	-- Telegraphs and world
	FarBell = { id = "", volume = 0.6, caption = "A far-off bus-stop bell" },
	WetSteps = { id = "", volume = 0.7, looped = true, caption = "Wet footsteps, running" },
	GlassSlap = { id = "", volume = 1, caption = "A hand slaps the glass" },
	DoorChime = { id = "", volume = 0.7, caption = "Door chime rings" },
	DryerThump = { id = "", volume = 0.8, looped = true, caption = "A dryer thumps out of rhythm" },
	Shush = { id = "", volume = 0.6, caption = "Shushing from the stacks" },
	CurtainRustle = { id = "", volume = 0.5, caption = "A curtain twitches" },
	IVSqueak = { id = "", volume = 0.6, looped = true, caption = "IV stand wheels squeaking" },
	ThreeKnocks = { id = "", volume = 0.9, caption = "Three knocks from inside a door" },
	EngineRev = { id = "", volume = 0.9, caption = "An engine revs" },
	EngineIdle = { id = "", volume = 0.5, looped = true, caption = "An engine idling" },
	PlasticCreak = { id = "", volume = 0.6, caption = "Plastic creaking" },
	WrenchTap = { id = "", volume = 0.6, looped = true, caption = "A wrench taps on pipes" },
	CornRustle = { id = "", volume = 0.6, caption = "Corn rustling behind you" },
	Bubbles = { id = "", volume = 0.6, caption = "Bubbles at your feet" },
	UnknownAnnouncement = { id = "", volume = 0.6, caption = "An announcement in an unknown language" },
	Breathing = { id = "", volume = 0.6, looped = true, caption = "Something breathing" },
	PhoneRing = { id = "", volume = 0.8, looped = true, caption = "A payphone ringing" },
	Jukebox = { id = "", volume = 0.4, looped = true, caption = "Music from an unplugged jukebox" },
	MonitorBeep = { id = "", volume = 0.5, looped = true, caption = "A heart monitor beeping" },
	MallMusic = { id = "", volume = 0.4, looped = true, caption = "Slow mall music" },
	BottleBreak = { id = "", volume = 0.9, caption = "Glass breaks" },
	FlareHiss = { id = "", volume = 0.6, looped = true, caption = "Flare hissing" },
	Footsteps = { id = "", volume = 0.6, caption = "Footsteps" },
	Whisper = { id = "", volume = 0.5, caption = "A whisper" },
	-- Entities and stops
	DryerBurst = { id = "", volume = 1, caption = "A dryer door bursts open" },
	Caught = { id = "", volume = 1, caption = "!" },
	EntitySpotted = { id = "", volume = 0.9, caption = "Something has seen you" },
	EntityStunned = { id = "", volume = 0.8, caption = "A shriek" },
	LightPop = { id = "", volume = 0.7, caption = "A streetlight pops" },
	LatecomerHiss = { id = "", volume = 0.8, caption = "A hiss" },
	LatecomerBoard = { id = "", volume = 1, caption = "Heavy steps board the bus" },
	EngineFar = { id = "", volume = 0.6, caption = "An engine, far away" },
	PingBlip = { id = "", volume = 0.5 },
	Ambience = { id = "", volume = 0.3, looped = true },
	LobbyAmbience = { id = "", volume = 0.3, looped = true },
}

return S
