--!strict
-- The depot kiosk and saved settings.
--   Kiosk remote (action, id, slot?):
--     "buy"    spend Tokens on a cosmetic that's sold for Tokens, then wear it
--     "equip"  wear an owned cosmetic in its slot
--     "remove" take off whatever is in a slot (id is the slot name)
--     "perk"   put an unlocked Perk in slot 1 or 2 ("none" empties slot 2)
--   Settings remote ({ key = value }): a whitelist of client settings, saved with the data.
-- Buying and Perk changes happen only in the lobby, never mid-run. Everything is checked
-- here; the client only asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local KioskService = {}

local Data: any
local PlayerState: any
local World: any

local byId: { [string]: any } = {}
for _, def in Config.Meta.Cosmetics do
	byId[def.id] = def
end
local perkById: { [string]: any } = {}
for _, def in Config.Meta.Perks do
	perkById[def.id] = def
end
local SLOTS: { [string]: boolean } = {}
for _, def in Config.Meta.Cosmetics do
	SLOTS[def.slot] = true
end

-- Client settings the server will save, with how to check each value.
local SETTINGS: { [string]: (any) -> boolean } = {
	captions = function(v)
		return type(v) == "boolean"
	end,
	dreadMeter = function(v)
		return type(v) == "boolean"
	end,
	reduceFlashing = function(v)
		return type(v) == "boolean"
	end,
	departureTimer = function(v)
		return type(v) == "boolean"
	end,
	sprintToggle = function(v)
		return type(v) == "boolean"
	end,
	masterVolume = function(v)
		return Net.isFiniteNumber(v) and v >= 0 and v <= 1
	end,
	sensitivity = function(v)
		return Net.isFiniteNumber(v) and v >= 0.2 and v <= 3
	end,
	effectsVolume = function(v)
		return Net.isFiniteNumber(v) and v >= 0 and v <= 1
	end,
	musicVolume = function(v)
		return Net.isFiniteNumber(v) and v >= 0 and v <= 1
	end,
	reduceScares = function(v)
		return type(v) == "boolean"
	end,
	soundIndicators = function(v)
		return type(v) == "boolean"
	end,
	sharePrompts = function(v)
		return type(v) == "boolean"
	end,
	headBob = function(v)
		return type(v) == "boolean"
	end,
	fov = function(v)
		return Net.isFiniteNumber(v) and v >= 70 and v <= 90
	end,
	brightness = function(v)
		return Net.isFiniteNumber(v) and v >= -0.2 and v <= 0.2
	end,
	calibrated = function(v)
		return type(v) == "boolean"
	end,
}

local function inLobby(player: Player): boolean
	local state = PlayerState.state(player)
	return state == "Lobby" or state == nil
end

local function toast(player: Player, text: string)
	Net.notify(player, "Toast", { text = text })
end

local function onKiosk(player: Player, action: any, id: any, slot: any)
	if type(action) ~= "string" or type(id) ~= "string" or #id > 40 then
		Net.drop(player)
		return
	end
	local data = Data.get(player)
	if not data then
		return
	end
	if action == "buy" then
		local def = byId[id]
		if not def then
			Net.drop(player)
			return
		end
		if not inLobby(player) then
			toast(player, "The kiosk is back at the depot.")
			return
		end
		if data.cosmetics.owned[id] then
			toast(player, "You already own that.")
			return
		end
		if def.price <= 0 then
			toast(player, if def.unlock then `Earned through: {def.unlock}.` else "That one isn't sold for Tokens.")
			return
		end
		if data.tokens < def.price then
			toast(player, `You need {def.price - data.tokens} more Tokens.`)
			return
		end
		Data.update(player, function(d: any)
			d.tokens -= def.price
			d.cosmetics.owned[id] = true
			d.cosmetics.equipped[def.slot] = id
			d.purchases[id] = os.time()
		end)
		Net.notify(player, "Sound", { key = "Kiosk" })
		toast(player, `Bought {def.name}.`)
		Log.info("Kiosk", player.Name, "bought", id, "for", def.price)
	elseif action == "equip" then
		local def = byId[id]
		if not def then
			Net.drop(player)
			return
		end
		if not data.cosmetics.owned[id] then
			toast(player, "You don't own that yet.")
			return
		end
		Data.update(player, function(d: any)
			d.cosmetics.equipped[def.slot] = id
		end)
	elseif action == "remove" then
		if not SLOTS[id] then
			Net.drop(player)
			return
		end
		Data.update(player, function(d: any)
			d.cosmetics.equipped[id] = nil
		end)
	elseif action == "perk" then
		if not Net.isInt(slot, 1, 2) then
			Net.drop(player)
			return
		end
		if not inLobby(player) then
			toast(player, "Perks can only be changed at the depot.")
			return
		end
		local n = slot :: number
		if n == 2 and data.rank < Config.Tuning.Ranks.SecondPerkAt then
			toast(player, `A second Perk opens at Rank {Config.Tuning.Ranks.SecondPerkAt}.`)
			return
		end
		if id == "none" then
			Data.update(player, function(d: any)
				if n == 1 then
					d.perks.equipped = {}
				else
					d.perks.equipped[2] = nil
				end
			end)
			return
		end
		if not perkById[id] then
			Net.drop(player)
			return
		end
		if not table.find(data.perks.unlocked, id) then
			toast(player, `{perkById[id].name} unlocks at Rank {perkById[id].rank}.`)
			return
		end
		Data.update(player, function(d: any)
			local eq = d.perks.equipped
			local other = if n == 1 then 2 else 1
			if eq[other] == id then
				eq[other] = eq[n] -- swap
			end
			eq[n] = id
			-- Keep the list dense.
			local dense = {}
			for i = 1, 2 do
				if eq[i] then
					table.insert(dense, eq[i])
				end
			end
			d.perks.equipped = dense
		end)
	else
		Net.drop(player)
	end
end

local function onSettings(player: Player, values: any)
	if type(values) ~= "table" then
		Net.drop(player)
		return
	end
	local clean: { [string]: any } = {}
	local count = 0
	for k, v in values do
		count += 1
		if count > 20 then
			break
		end
		local check = if type(k) == "string" then SETTINGS[k] else nil
		if check and check(v) then
			clean[k] = v
		end
	end
	Data.update(player, function(d: any)
		for k, v in clean do
			d.settings[k] = v
		end
	end)
end

local function buildKiosk()
	local lobby = World.Folders.Lobby
	local origin = CFrame.new(Config.Tuning.Lobby.Origin)
	local model = Build.model(lobby, "Kiosk")
	local at = origin * CFrame.new(4, 0, -26) * CFrame.Angles(0, math.rad(-90), 0)
	local function P(props: Build.PartProps): Part
		local p = table.clone(props)
		p.cf = at * (props.cf or CFrame.identity)
		p.group = "World"
		return Build.part(model, p)
	end
	P({
		name = "Base",
		size = Vector3.new(4, 0.6, 2.4),
		cf = CFrame.new(0, 0.3, 0),
		color = Color3.fromRGB(28, 30, 36),
		material = Enum.Material.Metal,
	})
	local body = P({
		name = "Body",
		size = Vector3.new(3.4, 6.4, 1.8),
		cf = CFrame.new(0, 3.8, 0),
		color = Color3.fromRGB(30, 70, 120),
		material = Enum.Material.SmoothPlastic,
	})
	local screen = P({
		name = "Screen",
		size = Vector3.new(2.6, 2, 0.1),
		cf = CFrame.new(0, 4.6, -0.92) * CFrame.Angles(math.rad(-8), 0, 0),
		color = Color3.fromRGB(255, 190, 80),
		material = Enum.Material.Neon,
		transparency = 0.2,
		collide = false,
	})
	Build.light(screen, "Point", Color3.fromRGB(255, 190, 80), 0.8, 10, false)
	local _, label = Build.sign(model, {
		name = "Header",
		size = Vector3.new(3.4, 0.9, 0.2),
		cf = at * CFrame.new(0, 7.4, -0.85),
		color = Color3.fromRGB(14, 14, 16),
		group = "World",
	}, "HCTA RIDER KIOSK", Enum.NormalId.Front, Color3.fromRGB(255, 190, 80), Enum.Font.Code)
	local _ = label
	P({
		name = "Slot",
		size = Vector3.new(1.4, 0.12, 0.3),
		cf = CFrame.new(0, 2.6, -0.95),
		color = Color3.fromRGB(10, 10, 12),
		material = Enum.Material.Metal,
	})
	local prompt = Build.prompt(body, "Open", "Rider Kiosk", 0, 9, "KioskPrompt")
	prompt.Triggered:Connect(function(player: Player)
		if inLobby(player) then
			Net.notify(player, "OpenMenu", { tab = "Kiosk" })
		end
	end)
end

function KioskService:Init()
	Data = Registry.get("DataService")
	PlayerState = Registry.get("PlayerStateService")
	World = Registry.get("WorldService")
end

function KioskService:Start()
	Net.on("Kiosk", onKiosk)
	Net.on("Settings", onSettings)
	Data.Loaded:Connect(function(player: Player, data: any)
		Net.notify(player, "Settings", data.settings)
	end)
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data then
			Net.notify(player, "Settings", data.settings)
		end
	end
	local ok, err = pcall(function()
		buildKiosk()
	end)
	if not ok then
		Log.warn("Kiosk", "couldn't build the kiosk:", err)
	end
end

return KioskService
