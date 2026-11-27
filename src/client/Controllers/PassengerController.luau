--!strict
-- Passengers, client side: their speech bubbles (with a caption line), blinking, and their
-- faint reflections in the bus windows at night. A mimic with the NeverBlinks tell never
-- closes its eyes; one with NoReflection has no reflection. Everything here is local.

local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Client = script.Parent.Parent
local Registry = require(Client:WaitForChild("Registry"))
local State = require(Client:WaitForChild("State"))
local Notify = require(Client:WaitForChild("Notify"))

local PassengerController = {}

local reflectFolder: Folder
local passengersFolder: Instance?

type Tracked = {
	model: Model,
	lids: { BasePart },
	nextBlink: number,
	blinkUntil: number,
	reflection: Model?,
	pairs: { { src: BasePart, copy: BasePart } },
}

local tracked: { [Model]: Tracked } = {}

local function lidsOf(m: Model): { BasePart }
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Lid") == true then
			table.insert(out, d)
		end
	end
	return out
end

local function isPassenger(m: Instance): boolean
	return m:IsA("Model") and m:GetAttribute("PassengerKey") ~= nil
end

local function dropReflection(t: Tracked)
	if t.reflection then
		t.reflection:Destroy()
		t.reflection = nil
	end
	table.clear(t.pairs)
end

-- A faint mirrored copy of the passenger's body, across the nearest side window.
local function makeReflection(t: Tracked)
	dropReflection(t)
	local copy = Instance.new("Model")
	copy.Name = "Reflection"
	for _, d in t.model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "ShadowBlob" then
			local p = Instance.new("Part")
			p.Size = d.Size
			p.Color = d.Color:Lerp(Color3.fromRGB(150, 170, 165), 0.35)
			p.Material = Enum.Material.SmoothPlastic
			p.Transparency = 0.82
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Parent = copy
			table.insert(t.pairs, { src = d :: BasePart, copy = p :: BasePart })
		end
	end
	copy.Parent = reflectFolder
	t.reflection = copy
end

local function track(m: Model)
	if tracked[m] then
		return
	end
	tracked[m] = {
		model = m,
		lids = lidsOf(m),
		nextBlink = os.clock() + math.random() * 4,
		blinkUntil = 0,
		reflection = nil,
		pairs = {},
	}
	m.Destroying:Connect(function()
		local t = tracked[m]
		if t then
			dropReflection(t)
		end
		tracked[m] = nil
	end)
end

local function scanFor(container: Instance)
	for _, d in container:GetDescendants() do
		if isPassenger(d) then
			track(d :: Model)
		end
	end
end

-- Mirror a CFrame across the plane x = w (in the interior's frame).
local function mirrored(cf: CFrame, w: number): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(2 * w - x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function step()
	local t0 = os.clock()
	local interior = State.busPart("Interior")
	local aboard = State.aboard()
	local bus = State.bus()
	local lightsOn = bus ~= nil and bus:GetAttribute("LightsOn") ~= false
	for m, t in tracked do
		if not m.Parent then
			continue
		end
		-- Blinking. A mimic with NeverBlinks keeps its eyes open.
		if m:GetAttribute("NeverBlinks") ~= true and #t.lids > 0 then
			if t0 >= t.nextBlink then
				t.blinkUntil = t0 + 0.13
				t.nextBlink = t0 + 2.5 + math.random() * 3.5
			end
			local shut = t0 < t.blinkUntil
			for _, lid in t.lids do
				lid.LocalTransparencyModifier = 0
				lid.Transparency = if shut then 0 else 1
			end
		end
		-- Reflections: only when you're aboard, the cabin lights are on, and it's inside.
		local inside = interior ~= nil
			and State.insideBus((m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart") :: BasePart).Position)
		local want = aboard and lightsOn and inside and m:GetAttribute("NoReflection") ~= true
		if want and interior then
			if not t.reflection then
				makeReflection(t)
			end
			local icf = interior.CFrame
			for _, pair in t.pairs do
				local rel = icf:ToObjectSpace(pair.src.CFrame)
				-- The bus is built along Z, so the side windows are the planes x = +-W/2.
				local w = (if rel.X >= 0 then 1 else -1) * interior.Size.X / 2
				local cf = mirrored(rel, w)
				pair.copy.CFrame = icf * cf
			end
		elseif t.reflection then
			dropReflection(t)
		end
	end
end

local function bubble(p: any)
	if type(p) ~= "table" or typeof(p.part) ~= "Instance" or type(p.text) ~= "string" then
		return
	end
	local part = p.part :: Instance
	if part:IsA("BasePart") and part.Parent then
		pcall(function()
			TextChatService:DisplayBubble(part, p.text)
		end)
	end
	local settings = Registry.find("SettingsController")
	if not settings or settings.get("captions") ~= false then
		local hud = Registry.find("HUDController")
		if hud and hud.caption then
			local name = if type(p.name) == "string" then p.name else "Passenger"
			hud.caption(name .. ": " .. p.text, Color3.fromRGB(220, 220, 200), 4)
		end
	end
end

-- Passenger models currently known (the mirror draws them).
function PassengerController.models(): { Model }
	local out = {}
	for m in tracked do
		if m.Parent then
			table.insert(out, m)
		end
	end
	return out
end

function PassengerController:Init()
	reflectFolder = Instance.new("Folder")
	reflectFolder.Name = "Reflections"
	reflectFolder.Parent = workspace
end

function PassengerController:Start()
	passengersFolder = workspace:WaitForChild("Passengers", 30)
	local function watch(container: Instance)
		scanFor(container)
		container.DescendantAdded:Connect(function(d: Instance)
			if isPassenger(d) then
				-- Attributes are set right after the model is parented; check next frame.
				task.defer(function()
					if d.Parent then
						track(d :: Model)
						local t = tracked[d :: Model]
						if t then
							t.lids = lidsOf(d :: Model)
						end
					end
				end)
			elseif d:IsA("Model") then
				task.defer(function()
					if isPassenger(d) then
						track(d :: Model)
					end
				end)
			end
		end)
	end
	if passengersFolder then
		watch(passengersFolder)
	end
	local busFolder = workspace:WaitForChild("Bus", 30)
	if busFolder then
		watch(busFolder)
	end
	Notify.on("Bubble", bubble)
	RunService.RenderStepped:Connect(step)
end

return PassengerController
