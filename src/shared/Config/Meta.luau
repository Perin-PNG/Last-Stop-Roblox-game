--!strict
-- Progression data: Perks, cosmetics, badges, endings, journal entries.

export type PerkDef = { id: string, name: string, rank: number, benefit: string, cost: string }
export type CosmeticDef = {
	id: string,
	name: string,
	slot: "flashlight" | "ticket" | "jacket" | "hat" | "voice" | "charm" | "livery" | "emote",
	price: number, -- Tokens; 0 = not sold for Tokens (pass or unlock)
	color: Color3?,
	pass: string?, -- product key in Config.Products if it comes with a pass
	unlock: string?, -- how else it is earned
}

local Perks: { PerkDef } = {
	{
		id = "light_sleeper",
		name = "Light Sleeper",
		rank = 3,
		benefit = "Hear the Latecomer's bell 3 seconds earlier",
		cost = "Footsteps are quieter to you",
	},
	{
		id = "medic",
		name = "Medic",
		rank = 6,
		benefit = "Field revives take 3 seconds instead of 5",
		cost = "One less inventory slot while carrying a medkit",
	},
	{
		id = "pack_mule",
		name = "Pack Mule",
		rank = 10,
		benefit = "Sprint at 70% speed while carrying fuel",
		cost = "Stamina regenerates slower",
	},
	{
		id = "steady_hands",
		name = "Steady Hands",
		rank = 14,
		benefit = "Polaroid photos develop instantly",
		cost = "One less shot of film per roll",
	},
	{
		id = "night_eyes",
		name = "Night Eyes",
		rank = 18,
		benefit = "Flashlight drains 25% slower",
		cost = "Narrower beam",
	},
	{
		id = "calm",
		name = "Calm",
		rank = 24,
		benefit = "Hallucinations start at 70 Dread instead of 60",
		cost = "Longer ping cooldown",
	},
}

local Cosmetics: { CosmeticDef } = {
	-- Flashlight beams: warm and cool whites only, so the horror lighting holds.
	{ id = "beam_warm", name = "Warm Beam", slot = "flashlight", price = 200, color = Color3.fromRGB(255, 226, 190) },
	{ id = "beam_cool", name = "Cool Beam", slot = "flashlight", price = 200, color = Color3.fromRGB(215, 232, 255) },
	{ id = "ticket_gold", name = "Gold Ticket", slot = "ticket", price = 350, color = Color3.fromRGB(230, 190, 80) },
	{
		id = "jacket_hcta",
		name = "HCTA Windbreaker",
		slot = "jacket",
		price = 600,
		color = Color3.fromRGB(30, 60, 100),
	},
	{ id = "hat_night_owl", name = "Night Owl Cap", slot = "hat", price = 450, color = Color3.fromRGB(25, 25, 30) },
	{ id = "charm_owl", name = "Owl Seat Charm", slot = "charm", price = 300, color = Color3.fromRGB(170, 130, 80) },
	{ id = "emote_wave", name = "Wave Goodbye", slot = "emote", price = 250 },
	{
		id = "jacket_commuter",
		name = "Commuter Jacket",
		slot = "jacket",
		price = 0,
		pass = "CommuterPass",
		color = Color3.fromRGB(120, 100, 60),
	},
	{
		id = "livery_dawn",
		name = "Dawn Livery",
		slot = "livery",
		price = 0,
		pass = "LiveryPack",
		color = Color3.fromRGB(240, 170, 110),
	},
	{
		id = "livery_fog",
		name = "Fog Livery",
		slot = "livery",
		price = 0,
		pass = "LiveryPack",
		color = Color3.fromRGB(150, 160, 165),
	},
	{
		id = "livery_ember",
		name = "Ember Livery",
		slot = "livery",
		price = 0,
		pass = "LiveryPack",
		color = Color3.fromRGB(120, 60, 40),
	},
	{ id = "voice_dispatch", name = "Dispatch Voice", slot = "voice", price = 0, pass = "VoicePackDispatch" },
	{
		id = "uniform_driver",
		name = "Driver's Uniform",
		slot = "jacket",
		price = 0,
		unlock = "Driver's Seat ending",
		color = Color3.fromRGB(40, 60, 90),
	},
	{
		id = "jacket_group",
		name = "Transit Authority Jacket",
		slot = "jacket",
		price = 0,
		unlock = "Join the Roblox group",
		color = Color3.fromRGB(70, 70, 75),
	},
	{
		id = "weekly_badge_pin",
		name = "Weekly Notice Pin",
		slot = "hat",
		price = 0,
		unlock = "Weekly challenges",
		color = Color3.fromRGB(200, 180, 60),
	},
}

local Badges: { [string]: { name: string, earnedBy: string } } = {
	FirstRide = { name = "First Ride", earnedBy = "Finishing the tutorial ride" },
	Home = { name = "Home", earnedBy = "The Home ending" },
	Transfer = { name = "Transfer", earnedBy = "The Transfer ending" },
	LastStop = { name = "Last Stop", earnedBy = "The Last Stop ending" },
	DriversSeat = { name = "Driver's Seat", earnedBy = "The secret ending" },
	BackFromTheBetween = { name = "Back From The Between", earnedBy = "Rejoining the bus after being Left Behind" },
	EyesFront = { name = "Eyes Front", earnedBy = "Finishing a run with zero mirror violations" },
	NotOnMyBus = { name = "Not On My Bus", earnedBy = "Escorting a mimic off" },
	LateFee = { name = "Late Fee", earnedBy = "Surviving a Latecomer boarding with nobody Lost" },
	Inspector = { name = "Inspector", earnedBy = "Photographing 50% of the Anomaly Catalog" },
	Lifer = { name = "Lifer", earnedBy = "Reaching Rank 31" },
}

local Endings: { [string]: { name: string, text: string } } = {
	Home = { name = "Home", text = "Everyone steps off at dawn. The Driver's seat is empty." },
	Transfer = {
		name = "Transfer",
		text = "The Lost wave from the windows of another bus heading back into the dark.",
	},
	LastStop = {
		name = "Last Stop",
		text = "The bus pulls into the Terminal with its passengers asleep. You among them. The doors close.",
	},
	DriversSeat = { name = "Driver's Seat", text = "The face in the mirror is yours." },
	Tutorial = { name = "End of the line, for now", text = "You learned the Rules. Ride for real." },
}

-- Journal: lore entries. Ids are referenced by the places that hand them out.
local Journal: { [string]: { title: string, text: string } } = {
	notice_rules = {
		title = "HCTA Notice 1",
		text = "Riders are reminded that the Rules are posted for your safety. The Rules change. Read them.",
	},
	radio_first = {
		title = "Dispatch, 1:58 AM",
		text = "Unit 9N, confirm passenger count. Unit 9N? ...Copy. Count confirmed. Count is wrong.",
	},
	gas_receipt = {
		title = "Gas & Go Receipt",
		text = "PUMP 2. 0.00 GAL. $0.00. THANK YOU FOR STOPPING. PLEASE STOP AGAIN.",
	},
	suds_note = {
		title = "Note Taped to Dryer 6",
		text = "OUT OF ORDER. DO NOT OPEN. IT IS NOT OUT OF ORDER.",
	},
	rosie_menu = {
		title = "Rosie's Menu, Back Page",
		text = "Open 24/7. Closed on the eighth day. Ask about the pie.",
	},
	library_card = {
		title = "Library Card",
		text = "Westbrook Public Library. Borrower: [smudged]. Checked out 1987. Due back: when you are.",
	},
	willow_flyer = {
		title = "Neighborhood Watch Flyer",
		text = "WILLOW COURT WATCH. We are always watching. Please keep your lights off.",
	},
	mercy_chart = {
		title = "Patient Chart",
		text = "Admitted 2:04 AM. Blind. Hearing acute. Do not discharge.",
	},
	motel_ledger = {
		title = "Motel Ledger",
		text = "Room 6. Checked in: yes. Checked out: no. Please do not knock back.",
	},
	rest_log = {
		title = "Maintenance Log",
		text = "Vending restocked. Hand removed. Hand restocked.",
	},
	mall_placard = {
		title = "Display Placard",
		text = "FALL COLLECTION. 4 FIGURES. If you count five, leave the store.",
	},
	depot_locker = {
		title = "Driver's Locker",
		text = "A uniform. A cap. A photo of a bus with every seat full. On the back: 'I only meant to drive.'",
	},
	farm_sign = {
		title = "Hollis Farm Sign",
		text = "PICK YOUR OWN. They pick their own too.",
	},
	elm_poster = {
		title = "Missing Poster",
		text = "Have you seen this rider? Last seen at Elm & 3rd, 1:58 AM, waiting for the 9N.",
	},
	low_water_tide = {
		title = "Tide Table",
		text = "Low Water Station. High tide: always rising.",
	},
	no_name_ticket = {
		title = "Ticket With No Name",
		text = "Valid for one ride. Destination: here.",
	},
	levelp_stub = {
		title = "Parking Stub",
		text = "Level P. Level P. Level P. Level P. Level P. Level P.",
	},
	graveyard_plate = {
		title = "Fleet Plate",
		text = "HCTA Unit 9. Retired 1987. Returned to service 1987.",
	},
	terminal_schedule = {
		title = "Terminal Schedule",
		text = "Route 9N terminates here. Drivers must be relieved. Drivers are relieved.",
	},
	clue_locker = {
		title = "Driver Clue: The Locker",
		text = "Locker 9 holds a name badge with the name scratched off. It was yours once, the note says.",
	},
	clue_off_duty = {
		title = "Driver Clue: Off Duty",
		text = "The off-duty driver told you three times: someone always takes the wheel.",
	},
	clue_true_channel = {
		title = "Driver Clue: True Channel",
		text = "On the true channel, dispatch calls Unit 9 by your name.",
	},
}

return {
	Perks = Perks,
	Cosmetics = Cosmetics,
	Badges = Badges,
	Endings = Endings,
	Journal = Journal,
	DriverClues = { "clue_locker", "clue_off_duty", "clue_true_channel" },
	CatalogRewardsAt = { 0.25, 0.5, 1 },
}
