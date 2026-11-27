--!strict
-- The Journal: lore entries a player keeps forever (Config.Meta.Journal). Notes found at
-- stops go straight in, for everyone in the run who is near enough to read along. Three of
-- the entries are the Driver clues for the secret ending:
--   clue_locker        open locker 9 at the Tri-County Bus Depot
--   clue_off_duty      talk to the Off-Duty Driver on three different runs
--   clue_true_channel  ride with the Sleeper's headphones and hear the true channel
-- Stops place their note with StopKit.lore; a stop that doesn't gets one pinned inside its
-- shelter (see LORE below).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local JournalService = {}

local Entries = Config.Meta.Journal
local Clues: { string } = Config.Meta.DriverClues

-- The lore note each stop holds.
JournalService.LORE = {
	gas_and_go = "gas_receipt",
	laundromat = "suds_note",
	diner = "rosie_menu",
	library = "library_card",
	willow_court = "willow_flyer",
	mercy_general = "mercy_chart",
	motel = "motel_ledger",
	rest_area = "rest_log",
	mall = "mall_placard",
	depot = "depot_locker",
	farm_stand = "farm_sign",
	elm_and_3rd = "elm_poster",
	low_water = "low_water_tide",
	no_name = "no_name_ticket",
	level_p = "levelp_stub",
	graveyard = "graveyard_plate",
	terminal = "terminal_schedule",
} :: { [string]: string }

local READ_ALONG = 30 -- studs: teammates this close to the reader get the entry too

local Data: any
local PlayerState: any
local offDutyThisRun: { [Player]: boolean } = {}
local trueChannelThisRun: { [Player]: boolean } = {}

function JournalService.has(player: Player, id: string): boolean
	local data = Data.get(player)
	return data ~= nil and data.journal[id] == true
end

function JournalService.cluesFound(player: Player): number
	local n = 0
	for _, id in Clues do
		if JournalService.has(player, id) then
			n += 1
		end
	end
	return n
end

function JournalService.allClues(player: Player): boolean
	return JournalService.cluesFound(player) == #Clues
end

-- Add an entry. Shows the note either way; only the first time is "new".
function JournalService.grant(player: Player, id: string, quiet: boolean?): boolean
	local entry = Entries[id]
	if not entry then
		return false
	end
	local data = Data.get(player)
	if not data then
		return false
	end
	local fresh = data.journal[id] ~= true
	if fresh then
		Data.update(player, function(d: any)
			d.journal[id] = true
		end)
		Log.info("Journal", player.Name, "found", id)
	end
	if not quiet then
		Net.notify(player, "Lore", { id = id, title = entry.title, text = entry.text, new = fresh })
	end
	if fresh and table.find(Clues, id) then
		local found = JournalService.cluesFound(player)
		Net.notify(player, "Toast", {
			text = if found == #Clues
				then "All three Driver clues. Watch the mirror on the way out."
				else string.format("Driver clue %d of %d.", found, #Clues),
		})
	end
	return fresh
end

-- Someone read a note: they and anyone close by get it.
function JournalService.read(reader: Player, id: string, at: Vector3)
	JournalService.grant(reader, id)
	for _, player in Players:GetPlayers() do
		if player ~= reader then
			local root = PlayerState.rootOf(player)
			if root and (root.Position - at).Magnitude <= READ_ALONG then
				JournalService.grant(player, id)
			end
		end
	end
end

-- A note on a part: a prompt that reads it.
function JournalService.attach(part: BasePart, id: string)
	local entry = Entries[id]
	if not entry then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LorePrompt"
	prompt.ActionText = "Read"
	prompt.ObjectText = entry.title
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		JournalService.read(player, id, part.Position)
	end)
end

-- The Off-Duty Driver: one talk counts per run, three runs make the clue.
function JournalService.offDutyTalk(player: Player)
	if offDutyThisRun[player] then
		return
	end
	offDutyThisRun[player] = true
	local talks = 0
	Data.update(player, function(d: any)
		d.offDutyTalks = (d.offDutyTalks or 0) + 1
		talks = d.offDutyTalks
	end)
	if talks >= 3 then
		JournalService.grant(player, "clue_off_duty")
	elseif not JournalService.has(player, "clue_off_duty") then
		Net.notify(player, "Toast", { text = "He looks at you like he's seen you before." })
	end
end

-- The Sleeper's headphones pick up the true channel on the ride.
local function trueChannel()
	local Inventory = Registry.find("InventoryService")
	if not Inventory then
		return
	end
	local lines = Config.Text.TrueChannel
	for _, player in Players:GetPlayers() do
		if not trueChannelThisRun[player] and Inventory.has(player, "headphones") then
			trueChannelThisRun[player] = true
			local line = lines[math.random(1, #lines)]
			task.delay(6, function()
				if player.Parent then
					Net.notify(player, "Radio", { text = line, channel = "true" })
					JournalService.grant(player, "clue_true_channel", true)
					JournalService.grant(player, "radio_first", true)
				end
			end)
		end
	end
end

function JournalService:Init()
	Data = Registry.get("DataService")
	PlayerState = Registry.get("PlayerStateService")
end

function JournalService:Start()
	local director = Registry.find("RunDirector")
	if director then
		director.RunStarted:Connect(function()
			table.clear(offDutyThisRun)
			table.clear(trueChannelThisRun)
		end)
		director.RideStarted:Connect(function(index: number)
			if index > 1 then
				trueChannel()
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		offDutyThisRun[player] = nil
		trueChannelThisRun[player] = nil
	end)
end

return JournalService
