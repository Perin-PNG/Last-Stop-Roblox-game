--!strict
-- Player settings. Kept on the client for now (saved with player data in M3). Other
-- controllers read them with SettingsController.get and listen with .changed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

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

function SettingsController.get(key: string): any
	return values[key]
end

function SettingsController.set(key: string, value: any)
	if values[key] == value then
		return
	end
	values[key] = value
	SettingsController.changed:Fire(key, value)
end

return SettingsController
