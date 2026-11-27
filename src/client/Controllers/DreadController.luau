--!strict
-- Fear on screen and in sound rather than a bar: a vignette and desaturation that grow
-- with Dread, a heartbeat above 60 and breathing above 85 (an optional small meter is a
-- setting). Also the fog of The Between while walking it.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local State = require(Client:WaitForChild("State"))
local Registry = require(Client:WaitForChild("Registry"))

local DreadController = {}

local vignette: Frame
local meter: Frame
local meterFill: Frame
local cc: ColorCorrectionEffect
local shown = 0
local heartbeat: Sound? = nil
local breath: Sound? = nil

local fogSaved: { start: number, finish: number, color: Color3, density: number? }? = nil

local function between(on: boolean)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if on and not fogSaved then
		fogSaved = {
			start = Lighting.FogStart,
			finish = Lighting.FogEnd,
			color = Lighting.FogColor,
			density = if atmosphere then atmosphere.Density else nil,
		}
		Lighting.FogStart = 4
		Lighting.FogEnd = 90
		Lighting.FogColor = Color3.fromRGB(40, 44, 50)
		if atmosphere then
			atmosphere.Density = 0.6
		end
	elseif not on and fogSaved then
		local saved = fogSaved :: any
		Lighting.FogStart = saved.start
		Lighting.FogEnd = saved.finish
		Lighting.FogColor = saved.color
		if atmosphere and saved.density then
			atmosphere.Density = saved.density
		end
		fogSaved = nil
	end
end

local function loop(key: string, want: boolean, current: Sound?): Sound?
	if want and not current then
		local audio = Registry.find("AudioController")
		return if audio then audio.play(key, nil, nil, true) else nil
	elseif not want and current then
		current:Destroy()
		return nil
	end
	return current
end

function DreadController:Init()
	local sg = Gui.screen("Dread", 6, true)
	-- Four gradient edges make the vignette, so no image asset is needed.
	vignette = Gui.frame(sg, { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	for i = 1, 4 do
		local edge = Gui.frame(sg, {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0,
			Size = if i <= 2 then UDim2.fromScale(1, 0.35) else UDim2.fromScale(0.35, 1),
			Position = if i == 1
				then UDim2.fromScale(0, 0)
				elseif i == 2 then UDim2.fromScale(0, 0.65)
				elseif i == 3 then UDim2.fromScale(0, 0)
				else UDim2.fromScale(0.65, 0),
			Name = "Edge" .. i,
		})
		local g = Instance.new("UIGradient")
		g.Rotation = if i == 1 then 90 elseif i == 2 then -90 elseif i == 3 then 0 else 180
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = edge
		edge.Parent = vignette
	end
	meter = Gui.frame(sg, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 50),
		Size = UDim2.fromOffset(90, 8),
		Visible = false,
	})
	Gui.corner(meter, 4)
	meterFill = Gui.frame(meter, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Gui.Colors.Danger })
	Gui.corner(meterFill, 4)
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DreadGrade"
	cc.Parent = workspace.CurrentCamera
end

function DreadController:Start()
	local Settings = Registry.get("SettingsController")
	RunService.RenderStepped:Connect(function(dt: number)
		local dread = (State.mine("Dread") :: number?) or 0
		local state = State.mine("State")
		if state == "Lobby" or state == "Static" then
			dread = 0
		end
		shown += (dread - shown) * math.min(1, dt * 2)
		local k = math.clamp(shown / 100, 0, 1)
		-- Vignette edges: invisible below 25, closing in above.
		local v = math.clamp((k - 0.25) / 0.75, 0, 1)
		vignette.Visible = v > 0.01
		for _, edge in vignette:GetChildren() do
			if edge:IsA("Frame") then
				edge.BackgroundTransparency = 1 - v * 0.85
			end
		end
		cc.Saturation = -0.5 * v
		cc.Contrast = 0.1 * v
		meter.Visible = Settings.get("dreadMeter") == true and state ~= "Lobby"
		meterFill.Size = UDim2.fromScale(k, 1)
		heartbeat = loop("Heartbeat", shown >= 60, heartbeat)
		breath = loop("Breath", shown >= 85, breath)
	end)
	State.watchMine("InBetween", function(on: any)
		between(on == true)
	end)
end

return DreadController
