--!strict
-- Creator Hub analytics: the First Ride onboarding funnel and a few custom events. Every
-- call is wrapped, so analytics never breaks the game (and Studio just logs).

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Log)

local AnalyticsHooks = {}

-- The First Ride steps, in order. Step numbers must stay stable once live.
AnalyticsHooks.Funnel = {
	"Offered",
	"Started",
	"ReadRules",
	"MetTheDriver",
	"GasAndGo",
	"PouredFuel",
	"Laundromat",
	"LoopCheck",
	"Finished",
}

local logged: { [Player]: { [number]: boolean } } = {}

-- Log a First Ride step once per player per session.
function AnalyticsHooks.funnel(player: Player, stepName: string)
	local step = table.find(AnalyticsHooks.Funnel, stepName)
	if not step then
		return
	end
	local seen = logged[player]
	if not seen then
		seen = {}
		logged[player] = seen
	end
	if seen[step] then
		return
	end
	seen[step] = true
	if RunService:IsStudio() then
		Log.info("Funnel", player.Name, step, stepName)
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
	if not ok then
		Log.warn("Funnel", "Log failed", err)
	end
end

-- A custom event (run ends, endings), for the Custom Events dashboard.
function AnalyticsHooks.event(player: Player, name: string, value: number?)
	if RunService:IsStudio() then
		return
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

function AnalyticsHooks.forget(player: Player)
	logged[player] = nil
end

function AnalyticsHooks:Init() end

function AnalyticsHooks:Start()
	game:GetService("Players").PlayerRemoving:Connect(AnalyticsHooks.forget)
end

return AnalyticsHooks
