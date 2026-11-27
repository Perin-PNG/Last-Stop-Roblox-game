--!strict
-- Static players watch the run on: the camera follows a living teammate (switch with the
-- arrows, 1-4 or the bumpers), with a light static grain over the screen. Pings still
-- work, so a Static player can still point things out.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local State = require(Client:WaitForChild("State"))
local Registry = require(Client:WaitForChild("Registry"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local SpectateController = {}

local bar: Frame
local nameLabel: TextLabel
local grain: Frame
local index = 1
local active = false
local watching: Player? = nil
local actions: Frame

local function watchable(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		local s = p:GetAttribute("State")
		if p ~= State.player and s ~= "Static" and s ~= "Lobby" and s ~= nil and p.Character then
			table.insert(out, p)
		end
	end
	return out
end

local function apply()
	local camera = workspace.CurrentCamera
	local list = watchable()
	if #list == 0 then
		-- Nobody to follow: watch the bus.
		local floor = State.busPart("Floor")
		if floor then
			camera.CameraSubject = floor
		end
		nameLabel.Text = "Watching the bus"
		watching = nil
		return
	end
	index = ((index - 1) % #list) + 1
	local target = list[index]
	watching = target
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	nameLabel.Text = "Watching " .. target.DisplayName
end

local function step(n: number)
	index += n
	apply()
end

local function setActive(on: boolean)
	if active == on then
		return
	end
	active = on
	bar.Visible = on
	grain.Visible = on
	local camera = Registry.get("CameraController")
	camera.spectating = on
	camera.refresh()
	if on then
		index = 1
		apply()
	else
		local character = State.character()
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			workspace.CurrentCamera.CameraSubject = humanoid
		end
	end
end

function SpectateController:Init()
	local sg = Gui.screen("Spectate", 20, true)
	grain = Gui.frame(sg, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(150, 160, 170),
		BackgroundTransparency = 0.93,
		Visible = false,
	})
	bar = Gui.frame(sg, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(360, 46),
		Visible = false,
	})
	Gui.corner(bar, 8)
	Gui.button(bar, "\u{25C0}", function()
		step(-1)
	end, { Size = UDim2.fromOffset(46, 46) })
	Gui.button(bar, "\u{25B6}", function()
		step(1)
	end, { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -46, 0, 0) })
	nameLabel = Gui.label(bar, "", {
		Size = UDim2.new(1, -100, 1, -8),
		Position = UDim2.fromOffset(50, 4),
		MaxText = 16,
	})
	local tag = Gui.label(sg, "YOU ARE STATIC", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -146),
		Size = UDim2.fromOffset(300, 24),
		Font = Gui.FontMono,
		TextColor3 = Gui.Colors.Dim,
		MaxText = 16,
	})
	tag.Visible = false
	-- Reaching through, once per stop: flicker a light near them, say one word on the
	-- radio, or flash the mimics aboard.
	actions = Gui.frame(sg, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -176),
		Size = UDim2.fromOffset(420, 34),
		BackgroundTransparency = 1,
		Visible = false,
	})
	Gui.list(actions, 6, true)
	local function action(text: string, fn: () -> ())
		Gui.button(actions, text, fn, { Size = UDim2.fromOffset(64, 34), TextSize = 12 })
	end
	action("Flicker", function()
		if watching then
			Net.event("GhostAction"):FireServer("flicker", watching.UserId)
		end
	end)
	for i, word in { "WAIT", "LEFT", "BEHIND", "NO" } do
		action(word, function()
			Net.event("GhostAction"):FireServer("word", i)
		end)
	end
	action("Reveal", function()
		Net.event("GhostAction"):FireServer("reveal")
	end)
	bar:GetPropertyChangedSignal("Visible"):Connect(function()
		tag.Visible = bar.Visible
		actions.Visible = bar.Visible
	end)
end

function SpectateController:Start()
	local Input = Registry.get("InputController")
	for n = 1, 4 do
		Input.on("Slot" .. n, function()
			if active then
				index = n
				apply()
			end
		end)
	end
	Input.on("SlotNext", function()
		if active then
			step(1)
		end
	end)
	Input.on("SlotPrev", function()
		if active then
			step(-1)
		end
	end)
	State.watchMine("State", function(s: any)
		setActive(s == "Static")
	end)
	-- Grain flicker, and re-pick when the watched teammate goes Static or leaves.
	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if not active then
			return
		end
		grain.BackgroundTransparency = 0.9 + math.random() * 0.06
		acc += dt
		if acc > 1 then
			acc = 0
			local subject = workspace.CurrentCamera.CameraSubject
			local model = subject and subject.Parent
			local p = model and Players:GetPlayerFromCharacter(model)
			if not p or p:GetAttribute("State") == "Static" then
				apply()
			end
		end
	end)
end

return SpectateController
