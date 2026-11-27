--!strict
-- The Driver's face, which exists only in the mirror. Each rider sees it on their own
-- screen: it starts to turn toward you as your Gaze climbs (2 seconds), and at 3 seconds
-- it's a violation. It is wrong in a different way each tier: too still, then smiling too
-- wide, then without eyes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local State = require(Client:WaitForChild("State"))
local Notify = require(Client:WaitForChild("Notify"))
local Gui = require(Client:WaitForChild("Gui"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Mirror = Config.Tuning.Mirror

local MirrorController = {}

type Face = {
	gui: SurfaceGui,
	head: Frame,
	eyes: { Frame },
	pupils: { Frame },
	mouth: Frame,
	cap: Frame,
	mirror: BasePart,
}

local face: Face? = nil
local turn = 0
local flash: Frame

local function f(parent: Instance, props: { [string]: any }): Frame
	local fr = Instance.new("Frame")
	fr.BorderSizePixel = 0
	for k, v in props do
		(fr :: any)[k] = v
	end
	fr.Parent = parent
	return fr
end

local function round(parent: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local function build(mirror: BasePart): Face
	local gui = Instance.new("SurfaceGui")
	gui.Name = "MirrorFace"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(550, 140)
	gui.LightInfluence = 0.6
	gui.Brightness = 1.2
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = true
	gui.Adornee = mirror
	gui.Parent = Gui.playerGui()
	-- A dim reflected cabin: the back of the bus, receding.
	local back = f(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(150, 160, 150),
		BackgroundTransparency = 0.82,
	})
	local _ = back
	local head = f(gui, {
		Name = "Head",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(74, 92),
		Position = UDim2.fromScale(0.3, 0.62),
		BackgroundColor3 = Color3.fromRGB(196, 178, 160),
	})
	round(head, 0.45)
	local cap = f(head, {
		Name = "Cap",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromScale(1.15, 0.32),
		Position = UDim2.fromScale(0.5, 0.24),
		BackgroundColor3 = Color3.fromRGB(28, 40, 62),
		ZIndex = 3,
	})
	round(cap, 0.3)
	f(cap, {
		Name = "Brim",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromScale(1.05, 0.3),
		Position = UDim2.fromScale(0.5, 0.9),
		BackgroundColor3 = Color3.fromRGB(16, 20, 30),
		ZIndex = 3,
	})
	local eyes, pupils = {}, {}
	for i, x in { 0.32, 0.68 } do
		local eye = f(head, {
			Name = "Eye" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.2, 0.09),
			Position = UDim2.fromScale(x, 0.42),
			BackgroundColor3 = Color3.fromRGB(230, 226, 214),
			ZIndex = 2,
		})
		round(eye, 0.5)
		local pupil = f(eye, {
			Name = "Pupil",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.42, 0.9),
			Position = UDim2.fromScale(0.15, 0.5), -- looking at the road
			BackgroundColor3 = Color3.fromRGB(20, 16, 14),
			ZIndex = 2,
		})
		round(pupil, 0.5)
		table.insert(eyes, eye)
		table.insert(pupils, pupil)
	end
	local mouth = f(head, {
		Name = "Mouth",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.34, 0.035),
		Position = UDim2.fromScale(0.5, 0.74),
		BackgroundColor3 = Color3.fromRGB(70, 36, 34),
		ZIndex = 2,
	})
	round(mouth, 0.5)
	-- Collar and shoulders.
	local collar = f(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(0.3, 0, 0.62, 46),
		BackgroundColor3 = Color3.fromRGB(32, 48, 72),
	})
	round(collar, 0.3)
	return { gui = gui, head = head, eyes = eyes, pupils = pupils, mouth = mouth, cap = cap, mirror = mirror }
end

local function clear()
	if face then
		face.gui:Destroy()
		face = nil
	end
end

local function tierLook(fc: Face, tier: number, t: number)
	-- Tier 1: too still. No blink, no sway, while the bus shakes.
	-- Tier 2: the smile is too wide.
	-- Tier 3: no eyes, only dark.
	local wide = tier >= 2
	local mouthW = if wide then 0.62 + 0.08 * turn else 0.34
	local mouthH = if wide then 0.07 + 0.05 * turn else 0.035
	fc.mouth.Size = UDim2.fromScale(mouthW, mouthH)
	fc.mouth.BackgroundColor3 = if wide then Color3.fromRGB(40, 10, 12) else Color3.fromRGB(70, 36, 34)
	for i, eye in fc.eyes do
		if tier >= 3 then
			eye.BackgroundColor3 = Color3.fromRGB(4, 4, 6)
			fc.pupils[i].Visible = false
			eye.Size = UDim2.fromScale(0.22, 0.14)
		else
			eye.BackgroundColor3 = Color3.fromRGB(230, 226, 214)
			fc.pupils[i].Visible = true
			-- Wider eyes as it turns.
			eye.Size = UDim2.fromScale(0.2, 0.09 + 0.07 * turn)
			-- Pupils slide from the road (left) to you (centre).
			fc.pupils[i].Position = UDim2.fromScale(0.15 + 0.35 * turn, 0.5)
		end
	end
	-- The head itself swings toward you a little and grows, as if leaning in.
	local scale = 1 + 0.25 * turn
	fc.head.Size = UDim2.fromOffset(74 * scale, 92 * scale)
	fc.head.Rotation = (1 - turn) * -6 + (if tier >= 2 then math.sin(t * 0.7) * 1.5 * turn else 0)
	fc.head.Position = UDim2.fromScale(0.3 + 0.12 * turn, 0.62 - 0.05 * turn)
end

local function step()
	local mirror = State.busPart("Mirror")
	if not mirror then
		clear()
		return
	end
	if not face or face.mirror ~= mirror then
		clear()
		face = build(mirror)
	end
	local fc = face :: Face
	local gaze = (State.mine("Gaze") :: number?) or 0
	local want = math.clamp((gaze - Mirror.TurnAt * 0.5) / (Mirror.ViolationAt - Mirror.TurnAt * 0.5), 0, 1)
	turn += (want - turn) * 0.15
	local tier = (State.get("Tier") :: number?) or 1
	tierLook(fc, tier, os.clock())
end

function MirrorController:Init()
	local sg = Gui.screen("MirrorFlash", 45, true)
	flash = Gui.frame(sg, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
	})
end

function MirrorController:Start()
	RunService.RenderStepped:Connect(step)
	Notify.on("MirrorTurn", function()
		Notify.emit("Hint", { id = "dont_watch" })
	end)
	Notify.on("MirrorViolation", function()
		flash.Visible = true
		flash.BackgroundTransparency = 0.35
		local tween = TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Once(function()
			flash.Visible = false
		end)
		Notify.emit("Sound", { key = "Sting" })
	end)
end

return MirrorController
