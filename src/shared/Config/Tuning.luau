--!strict
-- Every tunable number in the game. Change values here, not in scripts.
-- Values come from the build plan and are starting points for playtests.

local Tuning = {}

Tuning.Run = {
	MaxPlayers = 4,
	StopsBeforeTerminal = 11, -- stops 1-11, then the Terminal at 12
	FragmentsToWin = 5,
	MaxOvertimeLaps = 3, -- after this many laps without 5 fragments the run ends
	OvertimeStopsPerLap = 3,
	StartTransfers = 3,
	StartClockText = "1:58 AM",
	RouteJoinWait = 12, -- seconds the Route server waits for the whole party
	EndScreenSeconds = 25,
	SoloMinStartDelay = 3,
	Plan = "Slice", -- "Slice" (five stops, M1) or "Full" (11 stops and the Terminal)
	SliceFragmentsToWin = 1,
}

Tuning.Bus = {
	-- "Physics": the bus is unanchored and pulled along the road by AlignPosition and
	-- AlignOrientation. "Stationary": the M0 fallback. The bus stays anchored in place and
	-- scenery scrolls past on each client. Switch here if the M0 physics test fails.
	Mode = "Physics",
	CruiseSpeed = 58, -- studs/s
	Accel = 9, -- studs/s^2 when speeding up
	Brake = 11, -- studs/s^2 comfortable braking
	HoverHeight = 2.6, -- floor height above the road surface
	AlignResponsiveness = 60,
	AlignMaxForce = 1e9,
	AlignMaxTorque = 1e9,
	AlignRigid = false,
	LaneOffset = 9, -- bus lane centre is this far right of the road centre
	DoorOpenTime = 0.7,
	CordCloseDelay = 3, -- seconds after the second pull before the doors close
	CordPullWindow = 4, -- two pulls must land within this many seconds
	CordPerPlayerCooldown = 0.5,
	HoldPatiencePerSecond = 4,
	ScaleNote = "56 x 12 x 13 studs, aisle 5+ studs",
	InteriorPadding = 0.5,
	TankBars = 6,
	FuelPerRide = { 1, 1, 2 }, -- by tier
	FuelPourSeconds = 4,
	FuelPerCan = 2,
	FuelCapRange = 4,
	RecoveryBaySeconds = 10,
}

Tuning.Ride = {
	VoteWindow = 28, -- seconds the route vote stays open on the ride
	MinRideSeconds = 45,
	MaxRideSeconds = 75,
	EventChance = { 0.25, 0.4, 0.55 }, -- chance a ride rolls an event, by tier
	BlackoutSeconds = 12,
	InspectionWalkSeconds = 14,
	KnockSeconds = 10,
	StationaryRideSeconds = 50, -- ride length in Stationary mode
}

Tuning.Chunks = {
	Ahead = 3,
	Behind = 1,
	RoadWidth = 40,
	SidewalkWidth = 10,
	StraightLength = 420,
	CurveRadius = 760,
	CurveAngleDegrees = 28,
	HillLength = 480,
	HillHeight = 26,
	BridgeLength = 420,
	TunnelLength = 460,
	StopRoadLength = 520, -- stop chunk: curb is 300 studs from the entry
	StopCurbFromEntry = 300,
	TerminalLength = 900,
	WorldRadius = 7000, -- the road steers back toward the origin past this
	StreetlightSpacing = 70,
	SceneryDensity = 0.5,
}

Tuning.Stop = {
	DepartureTimer = { 120, 100, 85 }, -- by tier
	OvertimeTimer = 75,
	LatecomerAt = { 0.6, 0.45, 0.3 }, -- share of the timer, by tier
	OvertimeLatecomerAt = 0.25,
	BellsAt = { 30, 10 }, -- departure bell rings at these seconds left
	NoHazardNearCurb = 20,
	HazardTellRange = 10,
	LeftBehindAutoEnter = 15, -- seconds before a left-behind player is pulled into The Between
	BusWaitAtStall = true,
	StalledMinCans = 1,
	PassengerChance = { 0.2, 0.35, 0.5 },
	OvertimePassengerChance = 0.5,
}

Tuning.Patience = {
	Start = 100,
	Max = 100,
	RegainCleanStop = 10,
	MirrorViolation = 20,
	EscortRegular = 15,
	GasAndGoWrongCall = 15,
	FlickerAt = 75,
	OverrideAt = 50,
	TunnelAt = 25,
	ResetAfterZero = 60,
}

Tuning.Mirror = {
	Range = 25,
	ConeDegrees = 22, -- how close to the mirror the camera must point
	TurnAt = 2,
	ViolationAt = 3,
	DrainRate = 1.5, -- per second when looking away
}

Tuning.Gaze = {
	ReportHz = 10,
	MaxReportsPerSecond = 12,
	WatcherConeDegrees = 38,
	WatcherRange = 80,
	StaleAfter = 0.6, -- a report older than this counts as not looking
}

Tuning.Movement = {
	Walk = 12,
	Sprint = 20,
	Crouch = 7,
	Downed = 2,
	Carrying = 9,
	FuelCarry = 12, -- no sprint while carrying fuel
	PackMuleSprintShare = 0.7,
	StaminaSeconds = 6,
	StaminaRegenPerSecond = 1, -- seconds of stamina regained per second
	PackMuleRegenMultiplier = 0.7,
	CrouchCameraOffset = -1.6,
	JumpPower = 38,
	MaxSpeedOutsideBus = 30, -- movement sanity: flag faster than this for a second
	MaxJumpDistance = 50,
}

Tuning.Noise = {
	SprintRadius = 45,
	WalkRadius = 15,
	CrouchRadius = 0,
	LandRadius = 25,
	BottleRadius = 60,
	BookRadius = 50,
	DoorRadius = 30,
	DropRadius = 25,
	VoiceRadiusAtMax = 60,
	VoiceThreshold = 0.08,
	Lifetime = 4, -- seconds a noise event stays "recent"
	SampleHz = 4,
}

Tuning.Dread = {
	Max = 100,
	NoLight = 2,
	NoLightRadius = 10,
	AmbientAnomaly = 3,
	AmbientRadius = 18,
	Alone = 1,
	TeammateRadius = 30,
	TeammateNear = -1,
	BusLit = -3,
	BusLitSeated = -6,
	SeeTeammateDown = 15,
	Food = -30,
	TierMultiplier = { 1.0, 1.3, 1.6 },
	OvertimeMultiplier = 1.8,
	GraveyardMultiplier = 1.25,
	VignetteAt = 40,
	HallucinateAt = 60,
	CalmHallucinateAt = 70,
	FlickerAt = 80,
	PeakSeconds = 10,
	AfterPeak = 70,
	HallucinationEvery = { 14, 26 }, -- seconds between hallucinations above the threshold
	TickSeconds = 0.5,
}

Tuning.Player = {
	Health = 100,
	BleedOutSeconds = 60,
	CatchRange = 4,
	CarryPromptRange = 8,
	MedkitSeconds = 5,
	MedicMedkitSeconds = 3,
	GhostActionCooldownPerStop = 1,
	ReturnTicketCost = 15,
	FallDamagePerStud = 2,
	FallDamageMinHeight = 18,
	DownedHealth = 1,
}

Tuning.Items = {
	Slots = 4,
	FlashlightDrainPerSecond = 1, -- percent
	NightEyesDrainMultiplier = 0.75,
	BatteryRefill = 100,
	FlashlightRange = 46,
	FlashlightAngle = 52,
	NightEyesAngle = 40,
	FlashlightBrightness = 2.2,
	PolaroidFilm = 3,
	SteadyHandsFilm = 2,
	PhotoDevelopSeconds = 3,
	PhotoRange = 70,
	PhotoConeDegrees = 30,
	ThrowSpeed = 70,
	FlareSeconds = 20,
	FlareStunSeconds = 3,
	FlareStunRadius = 22,
	FlareLightRange = 36,
	UseCooldown = 0.6,
	PickupRange = 8,
	LostAndFoundPerRun = 1,
}

Tuning.Ping = {
	Lifetime = 6,
	Cooldown = 1.5,
	CalmCooldown = 2.5,
	MaxDistance = 150,
	MimicEchoRange = 22,
}

Tuning.Entities = {
	ActivePathfinders = 3,
	RepathSeconds = 0.5,
	TelegraphSeconds = 2,
	RecoverSeconds = 4,
	SightRange = 40,
	SightConeDegrees = 90,
	HunterChaseSpeed = { 17, 18, 19 },
	PatrolSpeed = 8,
	InvestigateSpeed = 11,
	ListenerSpeed = 10,
	WatcherSpeed = 26,
	SoloSpeedMultiplier = 0.85,
	TierSpeedMultiplier = { 1, 1.05, 1.1 },
	SentrySpotSeconds = 2,
	AmbusherRange = 7,
	LoseTargetSeconds = 4,
	WakeDelay = { 14, 10, 7 }, -- seconds after the doors open before a stop's threat wakes
}

Tuning.Latecomer = {
	StartDistance = 230, -- studs behind the curb along the sidewalk
	BoardedDownEvery = 8,
	KnockRadius = 5,
	BellLead = 0, -- extra seconds of warning (Light Sleeper adds 3)
	LightSleeperLead = 3,
}

Tuning.Passengers = {
	MaxAboard = 3,
	MimicShare = { 0.15, 0.35, 0.5 },
	OvertimeMimicShare = 0.6,
	DoppelChance = 0.12, -- of Tier 3 passengers
	AloneTriggerSeconds = 10,
	RandomActChancePerRide = 0.35, -- Tier 3
	EscortHoldSeconds = 3,
	RideStops = { 1, 3 },
}

Tuning.Between = {
	TargetSpareSeconds = 20, -- arrive about this long before the next departure
	WalkSpeedForLength = 13,
	MinLength = 220,
	MaxLength = 1600,
	SoloShorten = 0.8,
	PayphoneEvery = 260,
	PayphoneTalkSeconds = 10,
	HeadlightsEvery = 22,
	Origin = Vector3.new(16000, 0, 0),
}

Tuning.Rewards = {
	PerStop = 10,
	PerPhoto = 5,
	PerFragment = 20,
	Endings = { Home = 50, Transfer = 30, LastStop = 10, DriversSeat = 50 },
	FirstRunOfDayMultiplier = 2,
	FriendBonusEach = 0.1,
	FriendBonusMax = 0.3,
	CommuterPassBonus = 0.25,
	EvidenceTransfers = 2,
}

Tuning.Ranks = {
	-- XP needed for each rank grows gently: rank n needs Base * n^Exponent total XP.
	Base = 60,
	Exponent = 1.35,
	MaxRank = 60,
	Titles = {
		{ from = 1, title = "Rider" },
		{ from = 6, title = "Regular" },
		{ from = 16, title = "Night Owl" },
		{ from = 31, title = "Lifer" },
		{ from = 50, title = "Driver" },
	},
	SecondPerkAt = 16,
}

Tuning.Lobby = {
	QueueCountdown = 20,
	Origin = Vector3.new(-16000, 0, 0),
}

Tuning.Finale = {
	Breakers = 3,
	RoamingEntities = 2,
	DriveSeconds = 75,
	DriveSpeed = 50,
	DriveSteerSpeed = 14,
	DriveLaneHalfWidth = 13,
	LeakPerSecond = 0.06, -- tank bars per second during the drive
	ObstacleSlowSeconds = 1.6,
	PryEvery = 9,
	PryHoldSeconds = 4,
	SecretGazeSeconds = 3,
}

Tuning.Data = {
	AutosaveSeconds = 90,
	Retries = 5,
	LockStaleSeconds = 1800,
	StoreName = "PlayerData_v1",
	LeaderboardPrefix = "daily_",
}

Tuning.Analytics = {
	Enabled = true,
}

return Tuning
