--!strict
-- The rider menu: Kiosk (cosmetics for Tokens), Perks, Collections and Settings.
-- Opened from the depot kiosk, the menu button at the top right, or M / the gamepad's
-- Select button. Everything shown comes from Player attributes the server sets; every
-- change is a request the server checks (the Kiosk and Settings remotes).
-- Also plays the Wave Goodbye emote (B) in the lobby for riders who own it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local State = require(Client:WaitForChild("State"))
local Notify = require(Client:WaitForChild("Notify"))
local Registry = require(Client:WaitForChild("Registry"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Colors = Gui.Colors
local Meta = Config.Meta

local MenuController = {}

local Settings: any

local screen: ScreenGui
local panel: Frame
local header: TextLabel
local wallet: TextLabel
local body: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local closeButton: TextButton
local tab = "Kiosk"
local open = false
local TABS = { "Kiosk", "Perks", "Collections", "Settings" }

local function me(): Player
	return Players.LocalPlayer
end

local function csv(name: string): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local v = me():GetAttribute(name)
	if type(v) == "string" then
		for id in v:gmatch("[^,]+") do
			out[id] = true
		end
	end
	return out
end

local function inLobby(): boolean
	local s = State.mine("State")
	return s == nil or s == "Lobby"
end

local function kiosk(action: string, id: string, slot: number?)
	Net.event("Kiosk"):FireServer(action, id, slot)
end

-- Rows --------------------------------------------------------------------------------

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function section(text: string)
	Gui.label(body, text, {
		Size = UDim2.new(1, 0, 0, 26),
		Font = Gui.FontBold,
		MaxText = 16,
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
	})
end

local function note(text: string, color: Color3?)
	Gui.label(body, text, {
		Size = UDim2.new(1, 0, 0, 20),
		MaxText = 13,
		TextColor3 = color or Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
	})
end

-- A row: swatch, title, subtitle, and up to two buttons on the right.
type Button = { text: string, onClick: () -> (), primary: boolean? }
local function row(swatch: Color3?, title: string, sub: string, buttons: { Button }, dim: boolean?)
	local f = Gui.frame(body, {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Color3.fromRGB(24, 26, 34),
		BackgroundTransparency = 0.1,
		LayoutOrder = nextOrder(),
	})
	Gui.corner(f, 6)
	local left = 10
	if swatch then
		local s = Gui.frame(f, {
			Position = UDim2.fromOffset(10, 11),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = swatch,
			BackgroundTransparency = 0,
		})
		Gui.corner(s, 15)
		Gui.stroke(s, Color3.fromRGB(0, 0, 0), 1)
		left = 50
	end
	local width = #buttons * 92
	Gui.label(f, title, {
		Position = UDim2.fromOffset(left, 6),
		Size = UDim2.new(1, -(left + width + 10), 0, 22),
		Font = Gui.FontBold,
		MaxText = 16,
		TextColor3 = if dim then Colors.Dim else Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Gui.label(f, sub, {
		Position = UDim2.fromOffset(left, 28),
		Size = UDim2.new(1, -(left + width + 10), 0, 18),
		MaxText = 12,
		TextColor3 = Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for i, b in buttons do
		local btn = Gui.button(f, b.text, b.onClick, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10 - (#buttons - i) * 92, 0.5, 0),
			Size = UDim2.fromOffset(84, 32),
			MaxText = 14,
			BackgroundColor3 = if b.primary then Color3.fromRGB(150, 100, 30) else Color3.fromRGB(40, 44, 56),
		})
		local _ = btn
	end
end

-- Tabs --------------------------------------------------------------------------------

local function drawKiosk()
	local tokens = (me():GetAttribute("Tokens") :: number?) or 0
	local owned = csv("CosmeticsOwned")
	local lobby = inLobby()
	if not lobby then
		note("You can wear what you own anywhere. Buying waits for the depot.", Colors.Accent)
	end
	local bySlot: { [string]: { any } } = {}
	local slotOrder: { string } = {}
	for _, def in Meta.Cosmetics do
		if not bySlot[def.slot] then
			bySlot[def.slot] = {}
			table.insert(slotOrder, def.slot)
		end
		table.insert(bySlot[def.slot], def)
	end
	local SLOT_NAMES: { [string]: string } = {
		flashlight = "Flashlight beam",
		ticket = "Ticket",
		jacket = "Jackets",
		hat = "Hats and pins",
		charm = "Seat charms",
		livery = "Bus liveries (the party leader's is the one everyone rides)",
		emote = "Lobby emotes",
		voice = "Ping voices",
	}
	for _, slot in slotOrder do
		section(SLOT_NAMES[slot] or slot)
		local wearing = me():GetAttribute("Wear_" .. slot)
		for _, def in bySlot[slot] do
			local buttons: { Button } = {}
			local sub: string
			local dim = false
			if owned[def.id] then
				if wearing == def.id then
					sub = "Wearing"
					table.insert(buttons, {
						text = "Take off",
						onClick = function()
							kiosk("remove", slot)
						end,
					})
				else
					sub = "Owned"
					table.insert(buttons, {
						text = "Wear",
						primary = true,
						onClick = function()
							kiosk("equip", def.id)
						end,
					})
				end
				if def.slot == "emote" then
					table.insert(buttons, 1, {
						text = "Play (B)",
						onClick = function()
							MenuController.wave()
						end,
					})
				end
			elseif def.price > 0 then
				sub = `{def.price} Tokens`
				if tokens < def.price then
					sub ..= `  (need {def.price - tokens} more)`
					dim = true
				end
				if lobby then
					table.insert(buttons, {
						text = "Buy",
						primary = tokens >= def.price,
						onClick = function()
							kiosk("buy", def.id)
						end,
					})
				end
			elseif def.unlock then
				sub = `Earned through: {def.unlock}`
				dim = true
			else
				sub = "Comes with a pass (not on sale yet)"
				dim = true
			end
			row(def.color, def.name, sub, buttons, dim)
		end
	end
end

local function drawPerks()
	local rank = (me():GetAttribute("Rank") :: number?) or 1
	local unlocked = csv("PerksUnlocked")
	local p1, p2 = me():GetAttribute("Perk"), me():GetAttribute("Perk2")
	local two = rank >= Config.Tuning.Ranks.SecondPerkAt
	local lobby = inLobby()
	note(
		if two
			then "Equip two Perks. Each one has a cost, so none is strictly better."
			else `Equip one Perk. A second slot opens at Rank {Config.Tuning.Ranks.SecondPerkAt}. Each Perk has a cost.`
	)
	if not lobby then
		note("Perks can only be changed at the depot.", Colors.Accent)
	end
	for _, def in Meta.Perks do
		local buttons: { Button } = {}
		local status = ""
		if p1 == def.id then
			status = "  [slot 1]"
		elseif p2 == def.id then
			status = "  [slot 2]"
		end
		if unlocked[def.id] and lobby then
			if p1 == def.id or p2 == def.id then
				table.insert(buttons, {
					text = "Remove",
					onClick = function()
						if p1 == def.id then
							if p2 then
								kiosk("perk", p2 :: string, 1)
								kiosk("perk", "none", 2)
							else
								kiosk("perk", "none", 1)
							end
						else
							kiosk("perk", "none", 2)
						end
					end,
				})
			else
				table.insert(buttons, {
					text = if p1 then "Slot 1" else "Equip",
					primary = p1 == nil,
					onClick = function()
						kiosk("perk", def.id, 1)
					end,
				})
				if two and p1 then
					table.insert(buttons, {
						text = "Slot 2",
						primary = p2 == nil,
						onClick = function()
							kiosk("perk", def.id, 2)
						end,
					})
				end
			end
		end
		local locked = not unlocked[def.id]
		row(
			if locked then nil else Colors.Accent,
			def.name .. status .. (if locked then `  (Rank {def.rank})` else ""),
			`+ {def.benefit}.  - {def.cost}.`,
			buttons,
			locked
		)
	end
end

local function drawCollections()
	local rank = (me():GetAttribute("Rank") :: number?) or 1
	local xp = (me():GetAttribute("XP") :: number?) or 0
	local nextXP = (me():GetAttribute("NextRankXP") :: number?) or 0
	section(`Rank {rank}: {me():GetAttribute("RankTitle") or "Rider"}`)
	note(if rank >= Config.Tuning.Ranks.MaxRank then `{xp} XP. Top rank.` else `{xp} / {nextXP} XP to the next rank`)
	local anomalies = #Config.Anomalies.List
	local stops = 0
	for _ in Config.Stops.Stops do
		stops += 1
	end
	section("Anomaly Catalog")
	note(`{me():GetAttribute("CatalogCount") or 0} of {anomalies} anomalies photographed with the Polaroid.`)
	note("Rewards at 25%, 50% and 100%.")
	section("Route Map")
	note(`{me():GetAttribute("StopsVisited") or 0} of {stops} stops visited.`)
	section("Endings")
	local seen = csv("EndingsSeen")
	for _, id in { "Home", "Transfer", "LastStop", "DriversSeat" } do
		local def = Meta.Endings[id]
		if def then
			if seen[id] then
				row(Colors.Good, def.name, def.text, {})
			else
				row(nil, "???", "Not seen yet.", {}, true)
			end
		end
	end
	if me():GetAttribute("DataSaved") == false then
		note("Progress isn't saving in this server (Studio without API access).", Colors.Danger)
	end
end

type SettingDef = { key: string, name: string, hint: string }
local TOGGLES: { SettingDef } = {
	{ key = "captions", name = "Sound captions", hint = "Show text for important sounds" },
	{ key = "dreadMeter", name = "Dread meter", hint = "A small meter as well as the screen and sound cues" },
	{ key = "reduceFlashing", name = "Reduce flashing", hint = "Softer light flickers and hallucination flashes" },
	{ key = "departureTimer", name = "Departure timer", hint = "A countdown while you're off the bus" },
	{ key = "sprintToggle", name = "Toggle sprint", hint = "Tap to sprint instead of holding (always on for touch)" },
	{ key = "reduceScares", name = "Reduced jumpscares", hint = "Quieter stingers and no camera shake" },
	{
		key = "soundIndicators",
		name = "Sound indicators",
		hint = "An arrow toward important sounds, with their caption",
	},
	{ key = "headBob", name = "Head bob", hint = "Turn off if moving cameras make you feel sick" },
}

-- A setting stepped with - and + buttons.
local function stepper(
	key: string,
	name: string,
	hint: string,
	min: number,
	max: number,
	step: number,
	fmt: (number) -> string,
	default: number
)
	local value = (Settings.get(key) :: number?) or default
	local function set(v: number)
		Settings.set(key, math.clamp(math.floor(v / step + 0.5) * step, min, max))
	end
	row(nil, `{name}: {fmt(value)}`, hint, {
		{
			text = "-",
			onClick = function()
				set(value - step)
			end,
		},
		{
			text = "+",
			onClick = function()
				set(value + step)
			end,
		},
	})
end

local function percent(v: number): string
	return `{math.floor(v * 100 + 0.5)}%`
end

local function drawSettings()
	section("Accessibility and controls")
	for _, def in TOGGLES do
		local on = Settings.get(def.key) == true
		row(if on then Colors.Good else Color3.fromRGB(60, 60, 66), def.name, def.hint, {
			{
				text = if on then "On" else "Off",
				primary = on,
				onClick = function()
					Settings.set(def.key, not on)
				end,
			},
		})
	end
	section("Camera")
	stepper("fov", "Field of view", "How wide you see, 70 to 90", 70, 90, 5, function(v)
		return tostring(math.floor(v + 0.5))
	end, 70)
	stepper("sensitivity", "Camera sensitivity", "How fast the mouse turns the camera", 0.2, 3, 0.1, function(v)
		return string.format("%.1f", v)
	end, 1)
	row(nil, "Brightness", "Adjust until the symbol is barely visible", {
		{
			text = "Calibrate",
			onClick = function()
				local display = Registry.find("CalibrationController")
				if display then
					MenuController.hide()
					display.show()
				end
			end,
		},
	})
	section("Sound")
	stepper("masterVolume", "Master volume", "Everything in the game", 0, 1, 0.1, percent, 1)
	stepper("effectsVolume", "Effects volume", "The bus, the stops and everything in them", 0, 1, 0.1, percent, 1)
	stepper("musicVolume", "Music volume", "Music playing in the world", 0, 1, 0.1, percent, 1)
	row(nil, "Voice chat volume", "Set in the Roblox menu (Esc), under Settings", {})
end

local DRAW: { [string]: () -> () } = {
	Kiosk = drawKiosk,
	Perks = drawPerks,
	Collections = drawCollections,
	Settings = drawSettings,
}

local function redraw()
	if not open then
		return
	end
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	order = 0
	header.Text = if tab == "Kiosk" then "HCTA RIDER KIOSK" else string.upper(tab)
	local tokens = (me():GetAttribute("Tokens") :: number?) or 0
	wallet.Text = `{tokens} Tokens   Rank {me():GetAttribute("Rank") or 1}`
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == tab then Color3.fromRGB(150, 100, 30) else Color3.fromRGB(34, 36, 46)
	end
	local draw = DRAW[tab]
	local ok, err = pcall(function()
		draw()
	end)
	if not ok then
		warn("[Menu]", err)
	end
end

function MenuController.show(which: string?)
	if which and DRAW[which] then
		tab = which
	end
	open = true
	screen.Enabled = true
	closeButton.Modal = true -- frees the mouse in first person
	redraw()
	-- A gamepad needs a selected button to move around the menu.
	if UserInputService:GetLastInputType().Name:find("Gamepad") then
		GuiService.SelectedObject = tabButtons[tab] or closeButton
	end
end

function MenuController.hide()
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(screen) then
		GuiService.SelectedObject = nil
	end
	open = false
	screen.Enabled = false
	closeButton.Modal = false
end

function MenuController.toggle()
	if open then
		MenuController.hide()
	else
		MenuController.show()
	end
end

function MenuController.wave()
	if not inLobby() or not csv("CosmeticsOwned")["emote_wave"] then
		return
	end
	local character = me().Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animate = character and character:FindFirstChild("Animate")
	local wave = animate and animate:FindFirstChild("wave")
	local anim = wave and wave:FindFirstChildWhichIsA("Animation")
	if animator and anim then
		local track = animator:LoadAnimation(anim)
		track:Play()
		task.delay(3, function()
			track:Stop()
			track:Destroy()
		end)
	end
end

function MenuController:Init()
	Settings = Registry.get("SettingsController")
	screen = Gui.screen("Menu", 40)
	screen.Enabled = false
	panel = Gui.frame(screen, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.86),
		BackgroundColor3 = Color3.fromRGB(12, 13, 18),
		BackgroundTransparency = 0.04,
	})
	Gui.corner(panel, 10)
	Gui.stroke(panel, Color3.fromRGB(255, 176, 64), 1)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, 520)
	limit.Parent = panel
	header = Gui.label(panel, "HCTA RIDER KIOSK", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(0.5, -16, 0, 30),
		Font = Gui.FontMono,
		MaxText = 22,
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	wallet = Gui.label(panel, "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 12),
		Size = UDim2.new(0.5, -60, 0, 26),
		Font = Gui.FontBold,
		MaxText = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	closeButton = Gui.button(panel, "X", MenuController.hide, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 32),
	})
	local tabs = Gui.frame(panel, {
		Position = UDim2.fromOffset(16, 48),
		Size = UDim2.new(1, -32, 0, 34),
		BackgroundTransparency = 1,
	})
	Gui.list(tabs, 6, true)
	for i, name in TABS do
		tabButtons[name] = Gui.button(tabs, name, function()
			tab = name
			redraw()
		end, { Size = UDim2.new(0.25, -5, 1, 0), LayoutOrder = i, MaxText = 15 })
	end
	body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(16, 92)
	body.Size = UDim2.new(1, -32, 1, -104)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = panel
	Gui.list(body, 6)

	-- The menu button, top right, always there.
	local hud = Gui.screen("MenuButton", 11)
	Gui.button(hud, "MENU", MenuController.toggle, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(70, 30),
		MaxText = 13,
		BackgroundTransparency = 0.3,
	})
end

function MenuController:Start()
	Notify.on("OpenMenu", function(p: any)
		MenuController.show(if type(p) == "table" and type(p.tab) == "string" then p.tab else nil)
	end)
	for _, name in
		{
			"Tokens",
			"Rank",
			"XP",
			"CosmeticsOwned",
			"PerksUnlocked",
			"Perk",
			"Perk2",
			"State",
			"CatalogCount",
			"EndingsSeen",
		}
	do
		me():GetAttributeChangedSignal(name):Connect(redraw)
	end
	me().AttributeChanged:Connect(function(name: string)
		if name:sub(1, 5) == "Wear_" then
			redraw()
		end
	end)
	Settings.changed:Connect(function()
		if tab == "Settings" then
			redraw()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.ButtonSelect then
			MenuController.toggle()
		elseif input.KeyCode == Enum.KeyCode.B then
			MenuController.wave()
		elseif (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) and open then
			MenuController.hide()
		end
	end)
	local Input = Registry.find("InputController")
	if Input then
		Input.on("Menu", function()
			MenuController.toggle()
		end)
	end
end

return MenuController
