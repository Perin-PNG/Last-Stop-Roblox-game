--!strict
-- First Ride on the client: the one-line objective during the tutorial, and the offer a
-- new player sees in the lobby ("Take your First Ride?").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local State = require(Client:WaitForChild("State"))
local Notify = require(Client:WaitForChild("Notify"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local TutorialController = {}

local screen: ScreenGui
local objective: Frame
local objectiveText: TextLabel
local offer: Frame

local function showObjective(text: any)
	if type(text) ~= "string" or State.get("Mode") ~= "Tutorial" then
		objective.Visible = false
		return
	end
	objectiveText.Text = text
	objective.Visible = true
	objective.BackgroundTransparency = 0.6
	TweenService:Create(objective, TweenInfo.new(0.6), { BackgroundTransparency = 0.2 }):Play()
end

local function buildOffer()
	offer = Gui.frame(screen, {
		Name = "FirstRideOffer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(380, 200),
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	Gui.corner(offer, 12)
	Gui.stroke(offer, Color3.fromRGB(80, 200, 110), 2)
	Gui.label(offer, "FIRST RIDE", {
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 12),
		Font = Gui.FontBold,
		MaxText = 26,
		TextColor3 = Color3.fromRGB(120, 230, 140),
	})
	Gui.label(
		offer,
		"A short solo ride that teaches the Rules before you ride with others. About six minutes, and you can't fail it.",
		{
			Size = UDim2.new(1, -24, 0, 70),
			Position = UDim2.fromOffset(12, 50),
			MaxText = 17,
		}
	)
	local function close()
		offer.Visible = false
	end
	Gui.button(offer, "Ride now", function()
		close()
		Net.event("Tutorial"):FireServer("start")
	end, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(0.5, -18, 0, 44),
		BackgroundColor3 = Color3.fromRGB(40, 140, 70),
	})
	Gui.button(offer, "Later", function()
		close()
		Net.event("Tutorial"):FireServer("decline")
	end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0.5, -18, 0, 44),
	})
end

function TutorialController:Init()
	screen = Gui.screen("Tutorial", 7)
	objective = Gui.frame(screen, {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.new(0.9, 0, 0, 40),
		Visible = false,
	})
	Gui.corner(objective, 8)
	Gui.stroke(objective, Color3.fromRGB(80, 200, 110), 1)
	objectiveText = Gui.label(objective, "", {
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		MaxText = 18,
	})
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(520, 40)
	size.Parent = objective
	buildOffer()
end

function TutorialController:Start()
	State.watch("Objective", showObjective)
	State.on("Mode", function()
		showObjective(State.get("Objective"))
	end)
	Notify.on("OfferFirstRide", function()
		-- Wait until they're standing in the lobby.
		local tries = 0
		while State.mine("State") ~= "Lobby" and tries < 40 do
			tries += 1
			task.wait(0.5)
		end
		if State.mine("State") == "Lobby" then
			offer.Visible = true
		end
	end)
	State.watchMine("State", function(value: any)
		if value ~= "Lobby" then
			offer.Visible = false
		end
	end)
end

return TutorialController
