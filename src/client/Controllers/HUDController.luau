--!strict
-- The HUD stays nearly empty; most information lives in the world (clocks, bells, lights).
-- What's here: the four slots and battery at the bottom, teammate portraits at the top
-- left, a caption line for PA, radio and sounds, short toasts, one-time hints, the Down
-- overlay, a small departure countdown while off the bus (a setting), the vote reminder,
-- the stop-name card, and the end-of-run screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local State = require(Client:WaitForChild("State"))
local Notify = require(Client:WaitForChild("Notify"))
local Registry = require(Client:WaitForChild("Registry"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Text = Config.Text
local Colors = Gui.Colors

local HUDController = {}

local Inventory: any
local Settings: any

local root: ScreenGui
local slotFrames: { Frame } = {}
local slotLabels: { TextLabel } = {}
local battery: TextLabel
local pockets: TextLabel
local portraits: Frame
local captionBox: Frame
local toastLabel: TextLabel
local hintFrame: Frame
local hintLabel: TextLabel
local timerLabel: TextLabel
local voteLabel: TextLabel
local stopCard: TextLabel
local downFrame: Frame
local downLabel: TextLabel
local progressFrame: Frame
local progressFill: Frame
local progressLabel: TextLabel
local endFrame: Frame
local crosshair: Frame
local dropButton: TextButton

local seenHints: { [string]: boolean } = {}

-- Small helpers ----------------------------------------------------------------------------

local function fadeIn(obj: GuiObject, seconds: number)
	obj.Visible = true
	if obj:IsA("TextLabel") then
		obj.TextTransparency = 1
		TweenService:Create(obj, TweenInfo.new(seconds), { TextTransparency = 0 }):Play()
	end
end

local toastToken = 0
function HUDController.toast(text: string, color: Color3?, seconds: number?)
	toastToken += 1
	local my = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or Colors.Text
	fadeIn(toastLabel, 0.2)
	task.delay(seconds or 3, function()
		if toastToken == my then
			TweenService:Create(toastLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end

-- Caption lines stack above the slots and fade after a few seconds.
function HUDController.caption(text: string, color: Color3?, seconds: number?)
	local line = Gui.label(captionBox, text, {
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = color or Colors.Text,
		BackgroundTransparency = 0.45,
		BackgroundColor3 = Color3.new(0, 0, 0),
		MaxText = 18,
		LayoutOrder = math.floor(os.clock() * 10),
	})
	local lines = {}
	for _, c in captionBox:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(lines, c)
		end
	end
	if #lines > 4 then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end
	task.delay(seconds or 4, function()
		if line.Parent then
			local tween = TweenService:Create(line, TweenInfo.new(0.6), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			})
			tween:Play()
			tween.Completed:Once(function()
				line:Destroy()
			end)
		end
	end)
end

function HUDController.hint(id: string)
	if seenHints[id] then
		return
	end
	local text = (Text.Hints :: any)[id]
	if type(text) ~= "string" then
		return
	end
	seenHints[id] = true
	hintLabel.Text = text
	hintFrame.Visible = true
	hintFrame.BackgroundTransparency = 0.25
	task.delay(7, function()
		if hintLabel.Text == text then
			hintFrame.Visible = false
		end
	end)
end

-- Build ------------------------------------------------------------------------------------

local function buildSlots()
	local bar = Gui.frame(root, {
		Name = "Slots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(4 * 74 + 3 * 6, 64),
		BackgroundTransparency = 1,
	})
	Gui.list(bar, 6, true)
	for n = 1, 4 do
		local f = Gui.frame(bar, {
			Name = "Slot" .. n,
			Size = UDim2.fromOffset(74, 64),
			LayoutOrder = n,
			BackgroundTransparency = 0.4,
		})
		Gui.corner(f, 8)
		Gui.stroke(f, Color3.fromRGB(70, 70, 80), 1)
		Gui.label(f, tostring(n), {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(4, 2),
			TextColor3 = Colors.Dim,
			MaxText = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local l = Gui.label(f, "", {
			Size = UDim2.new(1, -8, 1, -18),
			Position = UDim2.fromOffset(4, 14),
			MaxText = 14,
			Font = Gui.FontBold,
		})
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.Parent = f
		hit.Activated:Connect(function()
			if Inventory.selected() == n and Registry.get("InputController").isTouch() then
				dropButton.Visible = not dropButton.Visible
			else
				dropButton.Visible = false
				Inventory.select(n)
			end
		end)
		slotFrames[n] = f
		slotLabels[n] = l
	end
	battery = Gui.label(root, "", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -(2 * 74 + 18), 1, -12),
		Size = UDim2.fromOffset(84, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxText = 16,
		Font = Gui.FontMono,
	})
	pockets = Gui.label(root, "", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -(2 * 74 + 18), 1, -44),
		Size = UDim2.fromOffset(110, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Colors.Dim,
		MaxText = 13,
		Font = Gui.FontMono,
	})
	dropButton = Gui.button(root, "Drop", function()
		dropButton.Visible = false
		local id = Inventory.selectedItem()
		if id then
			local Net = require(Shared:WaitForChild("Net"))
			Net.event("DropItem"):FireServer(Inventory.selected())
		end
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(90, 34),
		Visible = false,
	})
end

local function refreshSlots()
	local slots = Inventory.slots()
	local selected = Inventory.selected()
	for n = 1, 4 do
		local id = slots[n]
		local f = slotFrames[n]
		local l = slotLabels[n]
		local def = if id ~= "" and id ~= "+" then Config.Items[id] else nil
		if id == "+" then
			l.Text = "\u{2190}"
			l.TextColor3 = Colors.Dim
		elseif def then
			l.Text = def.name
			l.TextColor3 = Colors.Text
		else
			l.Text = ""
		end
		local stroke = f:FindFirstChildOfClass("UIStroke")
		local isSel = n == selected or (id == "+" and n - 1 == selected)
		if stroke then
			stroke.Color = if isSel then Colors.Accent else Color3.fromRGB(70, 70, 80)
			stroke.Thickness = if isSel then 2 else 1
		end
		f.BackgroundColor3 = if def then def.color:Lerp(Colors.Panel, 0.75) else Colors.Panel
	end
	local b = (State.mine("Battery") :: number?) or 0
	local on = State.mine("Light") == true
	battery.Text = string.format("%s %d%%", if on then "\u{25C9}" else "\u{25CB}", b)
	battery.TextColor3 = if b <= 15 then Colors.Danger elseif on then Colors.Accent else Colors.Dim
	local transfers = (State.mine("Transfers") :: number?) or 0
	local film = (State.mine("Film") :: number?) or 0
	local parts = {}
	if State.mine("Ticket") == false then
		table.insert(parts, "NO TICKET")
	end
	if transfers > 0 then
		table.insert(parts, transfers .. " transfers")
	end
	if film > 0 then
		table.insert(parts, film .. " film")
	end
	pockets.Text = table.concat(parts, "  ")
end

-- Teammates ------------------------------------------------------------------------------

local STATE_COLORS: { [string]: Color3 } = {
	Aboard = Color3.fromRGB(70, 160, 90),
	Outside = Color3.fromRGB(200, 170, 70),
	Downed = Color3.fromRGB(200, 50, 45),
	LeftBehind = Color3.fromRGB(120, 130, 150),
	Static = Color3.fromRGB(90, 90, 90),
	Lobby = Color3.fromRGB(70, 90, 120),
}

local function refreshPortraits()
	for _, c in portraits:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local me = State.mine("State")
	for i, p in Players:GetPlayers() do
		local s = p:GetAttribute("State")
		if type(s) == "string" and (s ~= "Lobby" or me == "Lobby") then
			local f = Gui.frame(portraits, {
				Size = UDim2.fromOffset(150, 30),
				LayoutOrder = if p == State.player then 0 else i,
				BackgroundTransparency = 0.35,
			})
			Gui.corner(f, 6)
			local dot = Gui.frame(f, {
				Size = UDim2.fromOffset(10, 10),
				Position = UDim2.new(0, 8, 0.5, -5),
				BackgroundColor3 = STATE_COLORS[s] or Colors.Dim,
				BackgroundTransparency = 0,
			})
			Gui.corner(dot, 5)
			local label = (Text.States :: any)[s] or s
			Gui.label(f, p.DisplayName .. "  \u{00B7}  " .. label, {
				Size = UDim2.new(1, -26, 1, -6),
				Position = UDim2.fromOffset(24, 3),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if s == "Static" then Colors.Dim else Colors.Text,
				MaxText = 13,
			})
		end
	end
end

local function watchPlayer(p: Player)
	p:GetAttributeChangedSignal("State"):Connect(refreshPortraits)
end

-- Per-frame text ---------------------------------------------------------------------------

local function stepTexts()
	local t = State.now()
	local phase = State.get("Phase")
	-- Departure countdown: only while off the bus (on the bus the bell and PA say it).
	local deadline = State.get("Deadline") :: number?
	local mine = State.mine("State")
	if Settings.get("departureTimer") and phase == "Stop" and deadline and (mine == "Outside" or mine == "Downed") then
		local left = deadline - t
		timerLabel.Visible = left > 0
		timerLabel.Text = "BUS LEAVES " .. Gui.clock(left)
		timerLabel.TextColor3 = if left <= 10 then Colors.Danger else Colors.Text
	elseif phase == "Stalled" then
		timerLabel.Visible = true
		timerLabel.Text = "OUT OF FUEL"
		timerLabel.TextColor3 = Colors.Danger
	else
		timerLabel.Visible = false
	end
	-- Vote reminder.
	if State.get("VoteOpen") == true then
		local a = Config.Stops.Stops[State.get("VoteA") or ""]
		local b = Config.Stops.Stops[State.get("VoteB") or ""]
		local voteLeft = ((State.get("VoteDeadline") :: number?) or t) - t
		voteLabel.Visible = true
		voteLabel.Text = string.format(
			"VOTE ON THE ROUTE BOARD  %s %d  \u{00B7}  %s %d   %s",
			if a then a.name else "?",
			(State.get("VoteCountA") :: number?) or 0,
			if b then b.name else "?",
			(State.get("VoteCountB") :: number?) or 0,
			Gui.clock(voteLeft)
		)
	else
		voteLabel.Visible = false
	end
	-- Down overlay.
	if mine == "Downed" then
		downFrame.Visible = true
		local recovering = State.mine("Recovering") :: number?
		local bleed = State.mine("BleedDeadline") :: number?
		if recovering then
			downLabel.Text = "Recovering in the bay  " .. Gui.clock(recovering - t)
		elseif State.mine("BleedPaused") == true then
			downLabel.Text = "You're Down, but safe on the bus.\nLie in the recovery bay at the back to get up."
		elseif bleed then
			downLabel.Text = "You're Down  " .. Gui.clock(bleed - t) .. "\nA teammate can carry you to the bus."
		end
	else
		downFrame.Visible = false
	end
	-- Crosshair dot in first person only.
	crosshair.Visible = mine == "Aboard" or mine == "Outside" or mine == "LeftBehind"
end

-- End screen ------------------------------------------------------------------------------

local function showEnd(summary: any)
	for _, c in endFrame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local ending = (Text.Endings :: any)[summary.ending] or { title = tostring(summary.ending), line = "" }
	endFrame.Visible = true
	endFrame.BackgroundTransparency = 1
	TweenService:Create(endFrame, TweenInfo.new(1.2), { BackgroundTransparency = 0.1 }):Play()
	Gui.list(endFrame, 10)
	Gui.label(endFrame, ending.title, {
		Size = UDim2.new(1, 0, 0, 64),
		Font = Enum.Font.GothamBlack,
		MaxText = 56,
		TextColor3 = if summary.ending == "Home" then Colors.Good else Colors.Danger,
		LayoutOrder = 1,
	})
	Gui.label(endFrame, ending.line, { Size = UDim2.new(1, 0, 0, 28), MaxText = 20, LayoutOrder = 2 })
	local stats = string.format(
		"Stops survived: %d     Fragments banked: %d/%d     Seed: %s",
		summary.stops or 0,
		summary.fragments or 0,
		(State.get("FragmentsNeeded") :: number?) or 5,
		tostring(summary.seed or "?")
	)
	Gui.label(endFrame, stats, {
		Size = UDim2.new(1, 0, 0, 24),
		MaxText = 16,
		TextColor3 = Colors.Dim,
		Font = Gui.FontMono,
		LayoutOrder = 3,
	})
	Gui.label(endFrame, "Back to the depot shortly.", {
		Size = UDim2.new(1, 0, 0, 22),
		MaxText = 14,
		TextColor3 = Colors.Dim,
		LayoutOrder = 10,
	})
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.3, 0)
	pad.Parent = endFrame
	task.delay(Config.Tuning.Run.EndScreenSeconds + 1, function()
		endFrame.Visible = false
	end)
end

-- The Token payout, added under the end screen's stats when the server sends it.
local function showRewards(p: any)
	if not endFrame.Visible then
		return
	end
	local old = endFrame:FindFirstChild("Rewards")
	if old then
		old:Destroy()
	end
	local box = Gui.frame(endFrame, {
		Name = "Rewards",
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 5,
	})
	Gui.list(box, 2)
	local order = 0
	local function row(text: string, color: Color3, size: number, font: Enum.Font?)
		order += 1
		Gui.label(box, text, {
			Size = UDim2.new(1, 0, 0, size + 6),
			MaxText = size,
			TextColor3 = color,
			Font = font or Gui.FontMono,
			LayoutOrder = order,
		})
	end
	if type(p.lines) == "table" then
		for _, line in p.lines do
			if type(line) == "table" then
				row(string.format("%-30s +%d", tostring(line.label), tonumber(line.amount) or 0), Colors.Dim, 14)
			end
		end
	end
	if type(p.notes) == "table" then
		for _, note in p.notes do
			row(tostring(note), Colors.Accent, 14)
		end
	end
	row(`+{tonumber(p.total) or 0} Tokens`, Colors.Good, 26, Enum.Font.GothamBlack)
	local xp, from, to = tonumber(p.xp) or 0, tonumber(p.thisRankXP) or 0, tonumber(p.nextRankXP) or 1
	local share = math.clamp((xp - from) / math.max(to - from, 1), 0, 1)
	row(
		`Rank {tonumber(p.rank) or 1} {tostring(p.title or "")}   {math.floor(share * 100)}% to the next`,
		Colors.Dim,
		14
	)
	order += 1
	local bar = Gui.frame(box, {
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(40, 40, 46),
		BackgroundTransparency = 0,
		LayoutOrder = order,
	})
	local fill = Gui.frame(bar, {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Colors.Good,
		BackgroundTransparency = 0,
	})
	TweenService:Create(fill, TweenInfo.new(1.5, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(share, 1) }):Play()
end

function HUDController:Init()
	Inventory = Registry.get("InventoryController")
	Settings = Registry.get("SettingsController")
	root = Gui.screen("HUD", 10)
	buildSlots()
	portraits = Gui.frame(root, {
		Name = "Team",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(150, 140),
		BackgroundTransparency = 1,
	})
	Gui.list(portraits, 4)
	captionBox = Gui.frame(root, {
		Name = "Captions",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -128),
		Size = UDim2.new(0.6, 0, 0, 130),
		BackgroundTransparency = 1,
	})
	local layout = Gui.list(captionBox, 3)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toastLabel = Gui.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0.6, 0, 0, 30),
		Font = Gui.FontBold,
		MaxText = 22,
		TextStrokeTransparency = 0.5,
		Visible = false,
	})
	hintFrame = Gui.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.new(0.5, 0, 0, 44),
		Visible = false,
	})
	Gui.corner(hintFrame, 8)
	Gui.stroke(hintFrame, Colors.Accent, 1)
	hintLabel =
		Gui.label(hintFrame, "", { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), MaxText = 17 })
	timerLabel = Gui.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(240, 28),
		Font = Gui.FontMono,
		MaxText = 22,
		TextStrokeTransparency = 0.4,
		Visible = false,
	})
	voteLabel = Gui.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(0.7, 0, 0, 24),
		Font = Gui.FontMono,
		MaxText = 15,
		TextColor3 = Colors.Accent,
		TextStrokeTransparency = 0.5,
		Visible = false,
	})
	stopCard = Gui.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.8, 0, 0, 60),
		Font = Enum.Font.GothamBlack,
		MaxText = 48,
		TextStrokeTransparency = 0.6,
		Visible = false,
	})
	local downSg = Gui.screen("Down", 8, true)
	downFrame = Gui.frame(downSg, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(70, 0, 0),
		BackgroundTransparency = 0.6,
		Visible = false,
	})
	downLabel = Gui.label(downFrame, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.7, 0, 0, 70),
		Font = Gui.FontBold,
		MaxText = 26,
		TextStrokeTransparency = 0.4,
	})
	progressFrame = Gui.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(260, 30),
		Visible = false,
	})
	Gui.corner(progressFrame, 6)
	progressFill = Gui.frame(progressFrame, {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Colors.Good,
		BackgroundTransparency = 0.2,
	})
	Gui.corner(progressFill, 6)
	progressLabel = Gui.label(progressFrame, "", { MaxText = 15, ZIndex = 2 })
	crosshair = Gui.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.5,
		Visible = false,
	})
	Gui.corner(crosshair, 2)
	local endSg = Gui.screen("EndScreen", 60, true)
	endFrame = Gui.frame(endSg, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
	})
end

local function progress(text: string, seconds: number)
	progressFrame.Visible = true
	progressLabel.Text = text
	progressFill.Size = UDim2.fromScale(0, 1)
	local tween = TweenService:Create(progressFill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 1),
	})
	tween:Play()
	tween.Completed:Once(function()
		progressFrame.Visible = false
	end)
end

function HUDController:Start()
	for _, name in { "Inventory", "Slot", "Battery", "Light", "Transfers", "Film", "Ticket" } do
		State.watchMine(name, function()
			refreshSlots()
		end)
	end
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(function(p)
		watchPlayer(p)
		refreshPortraits()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPortraits)
	end)
	refreshPortraits()
	RunService.RenderStepped:Connect(stepTexts)

	Notify.on("Toast", function(p: any)
		if type(p) == "table" and type(p.text) == "string" then
			HUDController.toast(p.text)
		end
	end)
	Notify.on("Hint", function(p: any)
		if type(p) == "table" and type(p.id) == "string" then
			HUDController.hint(p.id)
		end
	end)
	Notify.on("PA", function(p: any)
		if type(p) == "table" and type(p.text) == "string" then
			HUDController.caption("PA: " .. p.text, Color3.fromRGB(255, 210, 140), 5)
		end
	end)
	Notify.on("Radio", function(p: any)
		if type(p) == "table" and type(p.text) == "string" then
			local isTrue = p.channel == "true"
			HUDController.caption(
				(if isTrue then "Radio (?): " else "Radio: ") .. p.text,
				if isTrue then Color3.fromRGB(170, 220, 255) else Color3.fromRGB(180, 200, 170),
				if isTrue then 8 else 5
			)
		end
	end)
	Notify.on("Caption", function(p: any)
		if type(p) == "table" and type(p.text) == "string" then
			HUDController.caption("[" .. p.text .. "]", Colors.Dim, 3)
		end
	end)
	Notify.on("PingFeed", function(p: any)
		if type(p) == "table" then
			HUDController.caption(p.name .. ": " .. p.text, p.color, 3)
		end
	end)
	Notify.on("PatienceWarning", function(p: any)
		local level = if type(p) == "table" then p.level else 50
		local text = if level <= 25
			then "The Driver has had enough."
			elseif level <= 50 then "The Driver is losing patience."
			else "The Driver shifts in his seat."
		HUDController.toast(text, Colors.Danger, 4)
	end)
	Notify.on("RuleBroken", function(p: any)
		local rule = if type(p) == "table" then Config.Rules.ById[p.rule] else nil
		HUDController.toast(if rule then "Rule broken: " .. rule.text else "Rule broken.", Colors.Danger, 4)
	end)
	Notify.on("FragmentBanked", function(p: any)
		local total = if type(p) == "table" then p.total else 0
		HUDController.toast(
			string.format("Fragment banked (%d/%d)", total, (State.get("FragmentsNeeded") :: number?) or 5),
			Colors.Good
		)
	end)
	Notify.on("Downed", function(p: any)
		if type(p) == "table" and p.userId ~= State.player.UserId then
			local who = Players:GetPlayerByUserId(p.userId)
			HUDController.toast((if who then who.DisplayName else "Someone") .. " is Down.", Colors.Danger)
			HUDController.hint("teammate_down")
		end
	end)
	Notify.on("Lost", function(p: any)
		if type(p) == "table" and p.userId ~= State.player.UserId then
			local who = Players:GetPlayerByUserId(p.userId)
			HUDController.toast((if who then who.DisplayName else "Someone") .. " is Static.", Colors.Dim)
		elseif type(p) == "table" then
			HUDController.hint("lost")
		end
	end)
	Notify.on("Revived", function(p: any)
		if type(p) == "table" and p.userId == State.player.UserId then
			HUDController.toast("You're back on your feet.", Colors.Good)
		end
	end)
	Notify.on("CordClosing", function()
		HUDController.caption("[Ding, ding. Doors closing.]", Colors.Accent, 3)
	end)
	Notify.on("Progress", function(p: any)
		if type(p) == "table" and type(p.seconds) == "number" then
			progress(tostring(p.text or ""), p.seconds)
		end
	end)
	Notify.on("RunEnded", function(p: any)
		if type(p) == "table" then
			showEnd(p)
		end
	end)
	Notify.on("Rewards", function(p: any)
		if type(p) == "table" then
			showRewards(p)
		end
	end)
	Notify.on("RankUp", function(p: any)
		if type(p) == "table" then
			HUDController.toast(`Rank {tonumber(p.rank) or 0}: {tostring(p.title or "")}`, Colors.Good)
		end
	end)
	Notify.on("RunStarted", function()
		stopCard.Text = string.upper(Config.Route)
		fadeIn(stopCard, 1)
		task.delay(4, function()
			TweenService:Create(stopCard, TweenInfo.new(1), { TextTransparency = 1 }):Play()
		end)
	end)
	-- The stop-name card when the doors open somewhere new.
	State.on("StopName", function(name: any)
		if type(name) ~= "string" or name == "" then
			return
		end
		stopCard.Text = string.upper(name)
		fadeIn(stopCard, 0.8)
		task.delay(3, function()
			if stopCard.Text == string.upper(name) then
				TweenService:Create(stopCard, TweenInfo.new(1), { TextTransparency = 1 }):Play()
			end
		end)
	end)
end

return HUDController
