--!strict
-- The client's controller list, same idea as the server Registry.

local Registry = {}

Registry.Order = {
	"SettingsController",
	"InputController",
	"AudioController",
	"CameraController",
	"MovementController",
	"BusController",
	"SceneryController",
	"MirrorController",
	"GazeReporter",
	"VoiceReporter",
	"InventoryController",
	"DreadController",
	"HallucinationController",
	"PingController",
	"HUDController",
	"PromptController",
	"SpectateController",
	"TutorialController",
	"LobbyController",
	"ShareController",
	"DebugController",
}

local controllers: { [string]: any } = {}

function Registry.add(name: string, controller: any)
	controllers[name] = controller
end

function Registry.get(name: string): any
	local controller = controllers[name]
	assert(controller, "Unknown controller " .. name)
	return controller
end

function Registry.find(name: string): any?
	return controllers[name]
end

return Registry
