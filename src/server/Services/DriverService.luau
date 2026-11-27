--!strict
-- The Driver: the mirror rule, the shared Patience meter and its four thresholds, and the
-- PA. He never speaks except through calm announcements.
--
-- Mirror rule: each player's Gaze counter fills while their camera faces the mirror from
-- within 25 studs. At 2 seconds the reflected face starts to turn; at 3 it's a violation
-- (-20 Patience). Looking away drains the counter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Mirror = Config.Tuning.Mirror
local PTuning = Config.Tuning.Patience
local PA = Config.Text.PA

local DriverService = {}

DriverService.Violation = Signal.new() -- (player, reason, amount)
DriverService.Threshold = Signal.new() -- (75 | 50 | 25 | 0)

DriverService.cleanStop = true -- no violations since the last stop
DriverService.lastOffender = nil :: Player?
DriverService.overrideNextVote = false -- Patience 50
DriverService.forceTunnel = false -- Patience 25
DriverService.ejectNext = nil :: Player? -- Patience 0
DriverService.mirrorEnabled = true

local Bus: any
local RunState: Folder

local gaze: { [Player]: number } = {}
local turned: { [Player]: boolean } = {}

function DriverService.patience(): number
	return (RunState:GetAttribute("Patience") :: number?) or PTuning.Start
end

local function lightColor(p: number): Color3
	if p > 66 then
		return Color3.fromRGB(40, 220, 80)
	elseif p > 33 then
		return Color3.fromRGB(240, 170, 30)
	end
	return Color3.fromRGB(230, 40, 30)
end

local function updateLight()
	local refs = Bus.refs
	if refs then
		refs.patienceLight.Color = lightColor(DriverService.patience())
	end
end

function DriverService.say(text: string, kind: string?)
	Net.notifyAll("PA", { text = text, kind = kind })
end

function DriverService.radio(text: string)
	Net.notifyAll("Radio", { text = text })
end

function DriverService.setPatience(value: number)
	RunState:SetAttribute("Patience", math.clamp(math.floor(value + 0.5), 0, PTuning.Max))
	updateLight()
end

local function crossed(before: number, after: number, mark: number): boolean
	return before > mark and after <= mark
end

-- Change Patience. A negative change from a rule break remembers the offender.
function DriverService.change(delta: number, reason: string, offender: Player?)
	local mode = RunState:GetAttribute("Mode")
	if mode == "Tutorial" and delta < 0 then
		return
	end
	local before = DriverService.patience()
	local after = math.clamp(before + delta, 0, PTuning.Max)
	if delta < 0 then
		DriverService.cleanStop = false
		if offender then
			DriverService.lastOffender = offender
		end
	end
	DriverService.setPatience(after)
	if delta <= -1 then
		Log.info("Driver", "Patience", before, "->", after, reason)
	end
	if crossed(before, after, PTuning.FlickerAt) then
		DriverService.Threshold:Fire(75)
		Net.notifyAll("PatienceWarning", { level = 75 })
		task.spawn(function()
			for _ = 1, 6 do
				Bus.setLights(false)
				task.wait(0.08 + math.random() * 0.12)
				Bus.setLights(true)
				task.wait(0.1 + math.random() * 0.2)
			end
		end)
	end
	if crossed(before, after, PTuning.OverrideAt) then
		DriverService.overrideNextVote = true
		DriverService.Threshold:Fire(50)
		Net.notifyAll("PatienceWarning", { level = 50 })
	end
	if crossed(before, after, PTuning.TunnelAt) then
		DriverService.forceTunnel = true
		DriverService.Threshold:Fire(25)
		Net.notifyAll("PatienceWarning", { level = 25 })
	end
	if after <= 0 and before > 0 then
		DriverService.ejectNext = DriverService.lastOffender or offender
		DriverService.Threshold:Fire(0)
		DriverService.say(PA.patienceZero, "distorted")
	end
end

-- Called once a stop is over. A clean stop regains Patience.
function DriverService.endStop()
	if DriverService.cleanStop then
		DriverService.change(PTuning.RegainCleanStop, "clean stop")
	end
	DriverService.cleanStop = true
end

function DriverService.resetForRun()
	DriverService.cleanStop = true
	DriverService.lastOffender = nil
	DriverService.overrideNextVote = false
	DriverService.forceTunnel = false
	DriverService.ejectNext = nil
	DriverService.setPatience(PTuning.Start)
	table.clear(gaze)
	table.clear(turned)
end

-- After a Patience-zero ejection.
function DriverService.afterEject()
	DriverService.ejectNext = nil
	DriverService.setPatience(PTuning.ResetAfterZero)
end

local GazeService: any

local function mirrorTick(dt: number)
	local refs = Bus.refs
	if not refs or not GazeService then
		return
	end
	local target = refs.mirror.Position
	for _, player in Players:GetPlayers() do
		local g = gaze[player] or 0
		local state = player:GetAttribute("State")
		local looking = DriverService.mirrorEnabled
			and (state == "Aboard" or state == "Downed")
			and Bus.isAboard(player)
			and GazeService.isLookingAt(player, target, Mirror.ConeDegrees, Mirror.Range)
		if looking then
			g += dt
		else
			g = math.max(0, g - Mirror.DrainRate * dt)
		end
		if g >= Mirror.TurnAt and not turned[player] then
			turned[player] = true
			Net.notify(player, "MirrorTurn", {})
		elseif g < Mirror.TurnAt * 0.5 then
			turned[player] = false
		end
		if g >= Mirror.ViolationAt then
			g = 0
			turned[player] = false
			Net.notify(player, "MirrorViolation", {})
			DriverService.Violation:Fire(player, "mirror", Config.Tuning.Patience.MirrorViolation)
			DriverService.change(-PTuning.MirrorViolation, "mirror", player)
		end
		gaze[player] = g
		local shown = math.floor(g * 10 + 0.5) / 10
		if player:GetAttribute("Gaze") ~= shown then
			player:SetAttribute("Gaze", shown)
		end
	end
end

-- Break a posted Rule.
function DriverService.ruleBroken(player: Player, ruleId: string)
	local rule = Config.Rules.ById[ruleId]
	if not rule or rule.fake then
		return
	end
	Net.notify(player, "RuleBroken", { rule = ruleId })
	DriverService.Violation:Fire(player, ruleId, rule.patience)
	DriverService.change(-rule.patience, "rule " .. ruleId, player)
end

function DriverService:Init()
	Bus = Registry.get("BusService")
	RunState = Registry.get("WorldService").RunState
	GazeService = Registry.find("GazeService")
	RunState:SetAttribute("Patience", PTuning.Start)
end

function DriverService:Start()
	Bus.Spawned:Connect(function()
		updateLight()
	end)
	Players.PlayerRemoving:Connect(function(player)
		gaze[player] = nil
		turned[player] = nil
		if DriverService.lastOffender == player then
			DriverService.lastOffender = nil
		end
	end)
	task.spawn(function()
		while true do
			mirrorTick(task.wait(0.1))
		end
	end)
end

return DriverService
