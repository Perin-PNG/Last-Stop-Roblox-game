--!strict
-- Share prompts. When the server marks a clip-worthy moment (back from the Between, a
-- mimic escorted off, an ending), take a screenshot with CaptureService and show a small
-- card for a few seconds: "Share" opens the device's share sheet with the picture and an
-- invite to the game. Nothing is shared unless the player presses Share and then
-- confirms in Roblox's own sheet. Turned off with the Share prompts setting.

local CaptureService = game:GetService("CaptureService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local Notify = require(Client:WaitForChild("Notify"))
local Registry = require(Client:WaitForChild("Registry"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Log = require(Shared:WaitForChild("Log"))

local ShareController = {}

local SHOW_FOR = 9 -- seconds the card stays up
local COOLDOWN = 45 -- seconds between cards, except for endings

local TITLES: { [string]: string } = {
	returned = "Back from the Between",
	mimic = "Not on my bus",
	ending = "The end of the line",
}

local screen: ScreenGui
local card: Frame
local titleLabel: TextLabel
local busy = false
local lastShown = -math.huge
local pending: any = nil -- the capture waiting on the card
local shownToken = 0

local function hide()
	shownToken += 1
	card.Visible = false
	pending = nil
end

local function share()
	local capture = pending
	hide()
	if capture == nil then
		return
	end
	local ok, err = pcall(function()
		(CaptureService :: any):PromptShareCapture(capture, "share", function() end, function() end)
	end)
	if not ok then
		Log.warn("Share", "PromptShareCapture failed", err)
	end
end

local function show(title: string, capture: any)
	pending = capture
	titleLabel.Text = title
	card.Visible = true
	card.Position = UDim2.new(1, 20, 1, -150)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = UDim2.new(1, -16, 1, -150) })
		:Play()
	shownToken += 1
	local mine = shownToken
	task.delay(SHOW_FOR, function()
		if mine == shownToken then
			hide()
		end
	end)
end

local function onMoment(p: any)
	if type(p) ~= "table" or type(p.kind) ~= "string" or busy then
		return
	end
	local settings = Registry.find("SettingsController")
	if settings and settings.get("sharePrompts") == false then
		return
	end
	local now = os.clock()
	if p.kind ~= "ending" and now - lastShown < COOLDOWN then
		return
	end
	local title = TITLES[p.kind] or "A moment worth sharing"
	if p.kind == "ending" and type(p.ending) == "string" then
		local def = Config.Meta.Endings[p.ending]
		if def then
			title = `Ending: {def.name}`
		end
	end
	busy = true
	lastShown = now
	-- Take the picture first, with the card hidden, then offer it.
	if card.Visible then
		hide()
	end
	local ok, err = pcall(function()
		(CaptureService :: any):CaptureScreenshot(function(contentId: any)
			busy = false
			if contentId ~= nil then
				show(title, contentId)
			end
		end)
	end)
	if not ok then
		busy = false
		Log.warn("Share", "CaptureScreenshot failed", err)
	end
	-- If the capture never calls back, don't block the next moment forever.
	task.delay(5, function()
		busy = false
	end)
end

function ShareController:Init()
	screen = Gui.screen("Share", 8)
	card = Gui.frame(screen, {
		Name = "ShareCard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -150),
		Size = UDim2.fromOffset(250, 92),
		BackgroundTransparency = 0.15,
		Visible = false,
	})
	Gui.corner(card, 10)
	Gui.stroke(card, Color3.fromRGB(255, 200, 90), 1)
	titleLabel = Gui.label(card, "", {
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 8),
		Font = Gui.FontBold,
		MaxText = 18,
		TextColor3 = Color3.fromRGB(255, 210, 120),
	})
	Gui.button(card, "Share", share, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(0.62, -14, 0, 38),
		BackgroundColor3 = Color3.fromRGB(170, 120, 40),
	})
	Gui.button(card, "Not now", hide, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.new(0.38, -6, 0, 38),
	})
end

function ShareController:Start()
	Notify.on("ShareMoment", onMoment)
end

return ShareController
