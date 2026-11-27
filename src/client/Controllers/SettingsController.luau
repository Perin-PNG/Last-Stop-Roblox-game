--!strict
-- Player settings. The server saves them with the player's data and sends them back on
-- join. Other controllers read them with SettingsController.get and listen with .changed.
-- Changes go to the server in a batch at most every two seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local Notify = require(Client:WaitForChild("Notify"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Net = require(Shared:WaitForChild("Net"))

local SettingsController = {}

local values: { [string]: any } = {
	captions = true, -- sound captions
	dreadMeter = false, -- a small Dread meter instead of only screen and sound
	reduceFlashing = false,
	departureTimer = true, -- small countdown while off the bus
	masterVolume = 1,
	sprintToggle = false, -- touch defaults to toggle regardless
}

SettingsController.changed = Signal.new()

local dirty: { [string]: any } = {}
local flushing = false

local function flush()
	if next(dirty) == nil then
		flushing = false
		return
	end
	local batch = dirty
	dirty = {}
	Net.event("Settings"):FireServer(batch)
	task.delay(2, flush)
end

function SettingsController.get(key: string): any
	return values[key]
end

local function apply(key: string, value: any)
	if values[key] == value then
		return
	end
	values[key] = value
	SettingsController.changed:Fire(key, value)
end

function SettingsController.set(key: string, value: any)
	if values[key] == value then
		return
	end
	apply(key, value)
	dirty[key] = value
	if not flushing then
		flushing = true
		task.delay(0.5, flush)
	end
end

function SettingsController:Init() end

function SettingsController:Start()
	-- Saved settings arrive once the server has loaded the player's data.
	Notify.on("Settings", function(saved: any)
		if type(saved) ~= "table" then
			return
		end
		for key, value in saved do
			if type(key) == "string" and values[key] ~= nil and type(value) == type(values[key]) then
				apply(key, value)
			end
		end
	end)
end

return SettingsController
