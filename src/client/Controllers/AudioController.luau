--!strict
-- Plays sounds by key from Config.Audio, on a part, at a point, or flat. Every sound with
-- a caption also sends a "Caption" (shown by the HUD when captions are on), so the game
-- stays readable with empty sound ids and for deaf and hard-of-hearing players.
--
-- Also runs the bus loops: diesel hum and fluorescent buzz aboard, radio static that grows
-- as the Latecomer gets close (only with the pocket radio on), and outdoor ambience.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Client = script.Parent.Parent
local Notify = require(Client:WaitForChild("Notify"))
local State = require(Client:WaitForChild("State"))
local Registry = require(Client:WaitForChild("Registry"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local AudioController = {}

local Settings: any
local group: SoundGroup
local anchor: Part -- holds sounds played at a point

local function caption(def: any, key: string)
	if def and def.caption and Settings.get("captions") then
		Notify.emit("Caption", { text = def.caption, key = key })
	end
end

local function make(key: string, parent: Instance, looped: boolean?): Sound?
	local def = Config.Audio[key]
	if not def then
		return nil
	end
	if def.id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = def.id
	s.Volume = def.volume
	s.Looped = looped == true or def.looped == true
	s.SoundGroup = group
	s.RollOffMaxDistance = 140
	s.RollOffMinDistance = 8
	s.Parent = parent
	return s
end

-- Play a sound. part: on a part (3D); at: at a world point; neither: flat.
function AudioController.play(key: string, part: Instance?, at: Vector3?, loop: boolean?): Sound?
	local def = Config.Audio[key]
	caption(def, key)
	local parent: Instance = SoundService
	if part and part:IsA("BasePart") then
		parent = part
	elseif at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = anchor
		parent = a
		task.delay(12, function()
			a:Destroy()
		end)
	end
	local s = make(key, parent, loop)
	if not s then
		return nil
	end
	s:Play()
	if not s.Looped then
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	return s
end

-- A looped bed that fades by a 0..1 level each frame.
type Bed = { key: string, sound: Sound?, level: number }
local beds: { [string]: Bed } = {}

local function bed(key: string): Bed
	local existing = beds[key]
	if existing then
		return existing
	end
	local s = make(key, SoundService, true)
	if s then
		s.Volume = 0
		s:Play()
	end
	local b: Bed = { key = key, sound = s, level = 0 }
	beds[key] = b
	return b
end

local function setBed(key: string, level: number, dt: number)
	local b = bed(key)
	b.level += (level - b.level) * math.min(1, dt * 2)
	local s = b.sound
	if s then
		local def = Config.Audio[key]
		s.Volume = def.volume * b.level
	end
end

local function bedStep(dt: number)
	local aboard = State.aboard()
	local phase = State.get("Phase")
	local inRun = phase ~= nil and phase ~= "Idle"
	local speed = (State.get("BusSpeed") :: number?) or 0
	setBed("DieselHum", if inRun and aboard then 0.6 + math.clamp(speed / 50, 0, 0.4) else 0, dt)
	setBed("FluorBuzz", if inRun and aboard then 1 else 0, dt)
	setBed("Ambience", if inRun and not aboard then 1 else 0, dt)
	setBed("LobbyAmbience", if not inRun then 1 else 0, dt)
	-- Radio static: louder the closer the Latecomer gets.
	local distance = State.get("LatecomerDistance") :: number?
	local radio = State.mine("Radio") == true
	local level = 0
	if radio and distance then
		level = math.clamp(1 - distance / 160, 0.15, 1)
	end
	setBed("RadioStatic", level, dt)
end

function AudioController:Init()
	Settings = Registry.get("SettingsController")
	group = Instance.new("SoundGroup")
	group.Name = "Game"
	group.Volume = 1
	group.Parent = SoundService
	anchor = Instance.new("Part")
	anchor.Name = "SoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new()
	anchor.Parent = workspace
	Settings.changed:Connect(function(key: string, value: any)
		if key == "masterVolume" then
			group.Volume = value
		end
	end)
end

function AudioController:Start()
	Notify.on("Sound", function(payload: any)
		if type(payload) ~= "table" or type(payload.key) ~= "string" then
			return
		end
		AudioController.play(payload.key, payload.part, payload.at, payload.loop)
	end)
	Notify.on("Doors", function(payload: any)
		AudioController.play("DoorHiss", State.busPart("FrontDoorHeader") or State.busPart("Floor"))
		local _ = payload
	end)
	Notify.on("PA", function()
		AudioController.play("PAChime")
	end)
	RunService.Heartbeat:Connect(bedStep)
end

return AudioController
