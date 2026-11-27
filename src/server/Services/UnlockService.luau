--!strict
-- Cosmetics you earn instead of buy (Config.Meta.Cosmetics with a `pass` or `unlock`):
--   pass cosmetics       owned while the player has that game pass (MonetizationService
--                        sets the pass attribute)
--   uniform_driver       the Driver's Seat ending
--   jacket_group         being in the Roblox group (Config.Products.GroupId, 0 = off)
-- Each is added to the player's owned cosmetics once, with a toast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local UnlockService = {}

local Data: any

local function grant(player: Player, id: string)
	local data = Data.get(player)
	if not data or data.cosmetics.owned[id] then
		return
	end
	local name = id
	for _, def in Config.Meta.Cosmetics do
		if def.id == id then
			name = def.name
		end
	end
	Data.update(player, function(d: any)
		d.cosmetics.owned[id] = true
	end)
	Net.notify(player, "Toast", { text = `Unlocked: {name}. Wear it from the Kiosk.` })
	Log.info("Unlock", player.Name, id)
end

local function grantPass(player: Player, passKey: string)
	for _, def in Config.Meta.Cosmetics do
		if def.pass == passKey then
			grant(player, def.id)
		end
	end
end

local function checkAll(player: Player)
	for passKey in Config.Products.Passes :: any do
		if player:GetAttribute(passKey) == true then
			grantPass(player, passKey)
		end
	end
	local groupId = Config.Products.GroupId
	if groupId ~= 0 then
		local ok, inGroup = pcall(function()
			return player:IsInGroup(groupId)
		end)
		if ok and inGroup then
			grant(player, "jacket_group")
		end
	end
end

function UnlockService:Init()
	Data = Registry.get("DataService")
end

function UnlockService:Start()
	Data.Loaded:Connect(function(player: Player)
		task.spawn(checkAll, player)
	end)
	local function watch(player: Player)
		player.AttributeChanged:Connect(function(name: string)
			if (Config.Products.Passes :: any)[name] ~= nil and player:GetAttribute(name) == true then
				grantPass(player, name)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
		if Data.get(player) then
			task.spawn(checkAll, player)
		end
	end
	local director = Registry.find("RunDirector")
	if director then
		director.RunEnded:Connect(function(ending: string)
			if ending == "DriversSeat" then
				for _, player in director.runPlayers() do
					grant(player, "uniform_driver")
				end
			end
		end)
	end
end

return UnlockService
