--!strict
-- The depot: shows how to board and the departure countdown while you're in the lobby.

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local State = require(Client:WaitForChild("State"))

local RunService = game:GetService("RunService")

local LobbyController = {}

local label: TextLabel

function LobbyController:Init()
	local sg = Gui.screen("Lobby", 9)
	label = Gui.label(sg, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0.6, 0, 0, 30),
		Font = Gui.FontBold,
		MaxText = 22,
		TextStrokeTransparency = 0.5,
		Visible = false,
	})
end

function LobbyController:Start()
	RunService.RenderStepped:Connect(function()
		if State.mine("State") ~= "Lobby" then
			label.Visible = false
			return
		end
		label.Visible = true
		local ends = State.get("LobbyCountdown") :: number?
		local queued = (State.get("QueueCount") :: number?) or 0
		local phase = State.get("Phase")
		if ends then
			label.Text =
				string.format("The 9N departs in %d  \u{00B7}  %d in the bay", math.ceil(ends - State.now()), queued)
			label.TextColor3 = Gui.Colors.Accent
		elseif phase ~= nil and phase ~= "Idle" then
			label.Text = "A bus is out on the route. The next one is coming."
			label.TextColor3 = Gui.Colors.Dim
		else
			label.Text = "Stand in the yellow bay to board the 9N."
			label.TextColor3 = Gui.Colors.Text
		end
	end)
end

return LobbyController
