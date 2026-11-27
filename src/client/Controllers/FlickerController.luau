--!strict
-- Light flickers that run on each client, so Reduce flashing can soften them:
--   BusFlicker  the cabin lights stutter when the Driver's Patience drops past 75
--   Blink tag   an anomaly light that blinks (AnomalyService tags it while active)
-- With Reduce flashing on, a flicker is a slow dip instead of a strobe.
-- Nothing here changes the server's lights; when a flicker ends the lights go back to
-- what the server says.

local CollectionService = game:GetService("CollectionService")

local Client = script.Parent.Parent
local Notify = require(Client:WaitForChild("Notify"))
local Registry = require(Client:WaitForChild("Registry"))
local State = require(Client:WaitForChild("State"))

local FlickerController = {}

local DARK = Color3.fromRGB(30, 30, 32)

local function reduced(): boolean
	local settings = Registry.find("SettingsController")
	return settings ~= nil and settings.get("reduceFlashing") == true
end

type Saved = { lights: { [Light]: boolean }, parts: { [BasePart]: { color: Color3, material: Enum.Material } } }

local function capture(lights: { Light }, parts: { BasePart }): Saved
	local saved: Saved = { lights = {}, parts = {} }
	for _, light in lights do
		saved.lights[light] = light.Enabled
	end
	for _, part in parts do
		saved.parts[part] = { color = part.Color, material = part.Material }
	end
	return saved
end

local function setDark(saved: Saved, dark: boolean)
	for light, was in saved.lights do
		if light.Parent then
			light.Enabled = was and not dark
		end
	end
	for part, was in saved.parts do
		if part.Parent then
			part.Color = if dark then DARK else was.color
			part.Material = if dark then Enum.Material.SmoothPlastic else was.material
		end
	end
end

-- The bus cabin -----------------------------------------------------------------------------

local busFlickering = false

local function busFlicker(count: number)
	local bus = State.bus()
	if not bus or busFlickering then
		return
	end
	local lights: { Light } = {}
	local parts: { BasePart } = {}
	for _, d in bus:GetDescendants() do
		if d:GetAttribute("Bank") ~= nil then
			if d:IsA("Light") and d.Enabled then
				table.insert(lights, d)
			elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
				table.insert(parts, d)
			end
		end
	end
	local saved = capture(lights, parts)
	busFlickering = true
	if reduced() then
		for _ = 1, 2 do
			setDark(saved, true)
			task.wait(0.7)
			setDark(saved, false)
			task.wait(0.7)
		end
	else
		for _ = 1, count do
			setDark(saved, true)
			task.wait(0.08 + math.random() * 0.12)
			setDark(saved, false)
			task.wait(0.1 + math.random() * 0.2)
		end
	end
	setDark(saved, false)
	busFlickering = false
end

-- Blinking anomaly lights ---------------------------------------------------------------------

local blinking: { [Instance]: boolean } = {}

local function blink(target: Instance)
	if blinking[target] then
		return
	end
	blinking[target] = true
	local lights: { Light } = {}
	local parts: { BasePart } = {}
	local list = target:GetDescendants()
	table.insert(list, target)
	for _, d in list do
		if d:IsA("Light") then
			table.insert(lights, d)
		elseif d:IsA("BasePart") and d:GetAttribute("LitColor") ~= nil then
			table.insert(parts, d)
		end
	end
	local saved = capture(lights, parts)
	for part in saved.parts do
		local lit = part:GetAttribute("LitColor")
		if typeof(lit) == "Color3" then
			saved.parts[part].color = lit
			saved.parts[part].material = Enum.Material.Neon
		end
	end
	for light in saved.lights do
		saved.lights[light] = true
	end
	task.spawn(function()
		local dark = false
		while blinking[target] and target.Parent do
			dark = not dark
			setDark(saved, dark)
			if reduced() then
				task.wait(1.2)
			else
				task.wait(if dark then 0.05 + math.random() * 0.15 else 0.08 + math.random() * 0.3)
			end
		end
		setDark(saved, false)
	end)
end

local function unblink(target: Instance)
	blinking[target] = nil
end

function FlickerController:Init() end

function FlickerController:Start()
	Notify.on("BusFlicker", function(p: any)
		local count = if type(p) == "table" and type(p.count) == "number" then math.clamp(p.count, 1, 12) else 6
		task.spawn(busFlicker, count)
	end)
	CollectionService:GetInstanceAddedSignal("Blink"):Connect(blink)
	CollectionService:GetInstanceRemovedSignal("Blink"):Connect(unblink)
	for _, target in CollectionService:GetTagged("Blink") do
		blink(target)
	end
end

return FlickerController
