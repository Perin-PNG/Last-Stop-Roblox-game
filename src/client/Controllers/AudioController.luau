--!strict
-- Plays sounds by key from Config.Audio, on a part, at a point, or flat. Every sound with
-- a caption also sends a "Caption" (shown by the HUD when captions are on), so the game
-- stays readable with empty sound ids and for deaf and hard-of-hearing players.
--
-- Also runs the bus loops: diesel hum and fluorescent buzz aboard (both cut out in a
-- Blackout), radio static that grows as the Latecomer gets close (only with the pocket
-- radio on), and outdoor ambience.
--
-- Mixing: sounds go to one of three groups. Cabin (on the bus), Outside (anywhere else in
-- the world) and Flat (UI, stingers). With the doors shut, whichever side you're not on is
-- muffled by an equalizer, so the street sounds far away from your seat and the bus sounds
-- far away from the curb. The reverb follows where you stand: the bus, under a roof, the
-- open road, the depot, the Between. Parts tagged "Emitter" with an "Emit" attribute play
-- a quiet loop while they're lit and nearby (streetlight hum).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
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
local group: SoundGroup -- flat: UI, stingers, beds
local cabin: SoundGroup
local outside: SoundGroup
local cabinEq: EqualizerSoundEffect
local outsideEq: EqualizerSoundEffect
local anchor: Part -- holds sounds played at a point
local music: SoundGroup

-- Music, for the music volume setting; everything else is an effect.
local MUSIC = { MallMusic = true, Dawn = true }
-- Stingers that Reduced jumpscares plays quieter.
local SCARES = { Sting = true, Crash = true, LatecomerHiss = true, DoorCreak = true }

local function arrowTo(pos: Vector3): string
	local camera = workspace.CurrentCamera
	if not camera then
		return ""
	end
	local rel = camera.CFrame:PointToObjectSpace(pos)
	if Vector2.new(rel.X, rel.Z).Magnitude < 4 then
		return ""
	end
	local angle = math.deg(math.atan2(rel.X, -rel.Z))
	if angle > -35 and angle < 35 then
		return "\u{2191} "
	elseif angle >= 35 and angle <= 145 then
		return "\u{2192} "
	elseif angle <= -35 and angle >= -145 then
		return "\u{2190} "
	end
	return "\u{2193} "
end

local function groupFor(parent: Instance, key: string?): SoundGroup
	if key and MUSIC[key] then
		return music
	end
	if parent == SoundService then
		return group
	end
	local bus = workspace:FindFirstChild("Bus")
	if bus and parent:IsDescendantOf(bus) then
		return cabin
	end
	if parent:IsA("Attachment") and parent.Parent == anchor then
		local b = State.bus()
		if b and State.insideBus(parent.WorldPosition) then
			return cabin
		end
	end
	return outside
end

local function caption(def: any, key: string, pos: Vector3?)
	if not def or not def.caption then
		return
	end
	local indicators = Settings.get("soundIndicators") == true
	if Settings.get("captions") or indicators then
		local arrow = if indicators and pos then arrowTo(pos) else ""
		Notify.emit("Caption", { text = arrow .. def.caption, key = key })
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
	s.Volume = def.volume * (if SCARES[key] and Settings.get("reduceScares") then 0.35 else 1)
	s.Looped = looped == true or def.looped == true
	s.SoundGroup = groupFor(parent, key)
	s.RollOffMaxDistance = 140
	s.RollOffMinDistance = 8
	s.Parent = parent
	return s
end

-- Play a sound. part: on a part (3D); at: at a world point; neither: flat.
function AudioController.play(key: string, part: Instance?, at: Vector3?, loop: boolean?): Sound?
	local def = Config.Audio[key]
	local pos = if part and part:IsA("BasePart") then part.Position else at
	caption(def, key, pos)
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
	-- A looped sound needs somewhere to live and die with. If its part hasn't streamed in
	-- here, skip it rather than loop it flat forever (flat loops are beds, below).
	if parent == SoundService and (loop == true or (def and def.looped == true)) then
		return nil
	end
	local s = make(key, parent, loop)
	if not s then
		return nil
	end
	if parent:IsA("Attachment") then
		s.SoundGroup = groupFor(parent, key)
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
	local blackout = State.get("Blackout") == true
	setBed("DieselHum", if inRun and aboard and not blackout then 0.6 + math.clamp(speed / 50, 0, 0.4) else 0, dt)
	setBed("FluorBuzz", if inRun and aboard and not blackout then 1 else 0, dt)
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

-- Muffle and reverb --------------------------------------------------------------------

local function approach(current: number, target: number, rate: number): number
	return current + (target - current) * math.min(1, rate)
end

local function muffleStep(dt: number)
	local aboard = State.aboard()
	local doorsOpen = State.get("DoorsOpen") == true
	local bus = State.bus()
	-- How shut off each side is: 1 is fully muffled.
	local outsideTarget = if aboard and bus then (if doorsOpen then 0.25 else 1) else 0
	local cabinTarget = if not aboard and bus then (if doorsOpen then 0.3 else 0.9) else 0
	local rate = dt * 6
	outsideEq.HighGain = approach(outsideEq.HighGain, -30 * outsideTarget, rate)
	outsideEq.MidGain = approach(outsideEq.MidGain, -12 * outsideTarget, rate)
	outsideEq.LowGain = approach(outsideEq.LowGain, -2 * outsideTarget, rate)
	cabinEq.HighGain = approach(cabinEq.HighGain, -28 * cabinTarget, rate)
	cabinEq.MidGain = approach(cabinEq.MidGain, -10 * cabinTarget, rate)
	cabinEq.LowGain = approach(cabinEq.LowGain, -1 * cabinTarget, rate)
end

local roofParams = RaycastParams.new()
roofParams.FilterType = Enum.RaycastFilterType.Exclude
roofParams.RespectCanCollide = false

local function reverbFor(): Enum.ReverbType
	local state = State.mine("State")
	if state == "Static" then
		return Enum.ReverbType.Cave -- the Between, and spectating from it
	end
	if State.aboard() then
		return Enum.ReverbType.CarpettedHallway
	end
	local root = State.root()
	if not root then
		return Enum.ReverbType.Plain
	end
	local phase = State.get("Phase")
	local lobby = state == "Lobby" or phase == nil or phase == "Idle"
	roofParams.FilterDescendantsInstances = { State.player.Character :: Instance }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, 30, 0), roofParams)
	if hit and hit.Instance.Transparency < 1 then
		local height = hit.Position.Y - root.Position.Y
		if lobby then
			return Enum.ReverbType.ParkingLot -- under the depot canopy
		end
		return if height < 12 then Enum.ReverbType.Room else Enum.ReverbType.Hangar
	end
	if lobby then
		return Enum.ReverbType.City
	end
	return if (State.get("Tier") or 1) >= 3 then Enum.ReverbType.Mountains else Enum.ReverbType.Plain
end

-- Emitters -----------------------------------------------------------------------------

local emitting: { [BasePart]: Sound } = {}

local function lit(part: BasePart): boolean
	local light = part:FindFirstChildWhichIsA("Light")
	return light == nil or light.Enabled
end

local function emitterStep()
	local root = State.root()
	local at = if root then root.Position else nil
	for _, inst in CollectionService:GetTagged("Emitter") do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			local near = at ~= nil and (inst.Position - at).Magnitude < 90
			local sound = emitting[inst]
			if near and lit(inst) then
				if not sound then
					local key = inst:GetAttribute("Emit")
					local made = if type(key) == "string" then make(key, inst, true) else nil
					if made then
						made.RollOffMinDistance = 4
						made.RollOffMaxDistance = 60
						made:Play()
						emitting[inst] = made
					end
				end
			elseif sound then
				sound:Destroy()
				emitting[inst] = nil
			end
		end
	end
	for part, sound in emitting do
		if not part:IsDescendantOf(workspace) then
			sound:Destroy()
			emitting[part] = nil
		end
	end
end

function AudioController:Init()
	Settings = Registry.get("SettingsController")
	group = Instance.new("SoundGroup")
	group.Name = "Game"
	group.Volume = 1
	group.Parent = SoundService
	cabin = Instance.new("SoundGroup")
	cabin.Name = "Cabin"
	cabin.Parent = SoundService
	cabinEq = Instance.new("EqualizerSoundEffect")
	cabinEq.HighGain, cabinEq.MidGain, cabinEq.LowGain = 0, 0, 0
	cabinEq.Parent = cabin
	outside = Instance.new("SoundGroup")
	outside.Name = "Outside"
	outside.Parent = SoundService
	outsideEq = Instance.new("EqualizerSoundEffect")
	outsideEq.HighGain, outsideEq.MidGain, outsideEq.LowGain = 0, 0, 0
	outsideEq.Parent = outside
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
	music = Instance.new("SoundGroup")
	music.Name = "Music"
	music.Parent = SoundService
	local function volumes()
		local master = (Settings.get("masterVolume") :: number?) or 1
		local effects = master * ((Settings.get("effectsVolume") :: number?) or 1)
		group.Volume = effects
		cabin.Volume = effects
		outside.Volume = effects
		music.Volume = master * ((Settings.get("musicVolume") :: number?) or 1)
		-- Other players' voices, when voice chat runs through the audio API. The change
		-- is local, so it only sets what this player hears.
		local voice = (Settings.get("voiceVolume") :: number?) or 1
		for _, other in Players:GetPlayers() do
			if other ~= Players.LocalPlayer then
				for _, d in other:GetDescendants() do
					if d:IsA("AudioDeviceInput") then
						pcall(function()
							d.Volume = voice
						end)
					end
				end
			end
		end
	end
	volumes()
	Settings.changed:Connect(function(key: string)
		if
			key == "masterVolume"
			or key == "effectsVolume"
			or key == "musicVolume"
			or key == "voiceVolume"
			or key == "loaded"
		then
			volumes()
		end
	end)
	Players.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("AudioDeviceInput") and not d:IsDescendantOf(Players.LocalPlayer) then
			local voice = (Settings.get("voiceVolume") :: number?) or 1
			pcall(function()
				d.Volume = voice
			end)
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
	RunService.Heartbeat:Connect(function(dt: number)
		bedStep(dt)
		muffleStep(dt)
	end)
	task.spawn(function()
		while true do
			pcall(function()
				SoundService.AmbientReverb = reverbFor()
				emitterStep()
			end)
			task.wait(0.5)
		end
	end)
end

return AudioController
