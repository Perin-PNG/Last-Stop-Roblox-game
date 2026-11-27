--!strict
-- The Route Map wall in the depot (plan, "Route Map"). The board is a blank part the
-- server builds (Lobby.Depot.RouteMap); this draws a SurfaceGui on it for this player
-- only, stamping every stop they've visited (the StopIds attribute). Unvisited stops
-- show as "???" so the map is something to fill in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local RouteMapController = {}

local INK = Color3.fromRGB(40, 38, 34)
local FAINT = Color3.fromRGB(150, 146, 134)
local STAMP = Color3.fromRGB(190, 40, 40)

local player = Players.LocalPlayer
local surface: SurfaceGui? = nil
local columns: { Frame } = {}

local function visited(): { [string]: boolean }
	local out = {}
	local raw = player:GetAttribute("StopIds")
	if type(raw) == "string" then
		for id in string.gmatch(raw, "[^,]+") do
			out[id] = true
		end
	end
	return out
end

local function draw()
	local gui = surface
	if not gui then
		return
	end
	for _, col in columns do
		col:Destroy()
	end
	table.clear(columns)
	local seen = visited()
	local groups: { { title: string, ids: { string } } } = {
		{ title = "ALWAYS", ids = { "gas_and_go", "terminal" } },
		{ title = "TIER 1", ids = Config.Stops.Pools[1] or {} },
		{ title = "TIER 2", ids = Config.Stops.Pools[2] or {} },
		{ title = "TIER 3", ids = Config.Stops.Pools[3] or {} },
	}
	local total, got = 0, 0
	for i, group in groups do
		local col = Gui.frame(gui, {
			Name = group.title,
			BackgroundTransparency = 1,
			Position = UDim2.new((i - 1) / #groups, 8, 0, 110),
			Size = UDim2.new(1 / #groups, -16, 1, -130),
		})
		table.insert(columns, col)
		Gui.label(col, group.title, {
			Size = UDim2.new(1, 0, 0, 34),
			Font = Gui.FontBold,
			TextColor3 = INK,
			MaxText = 30,
		})
		for j, id in group.ids do
			local def = Config.Stops.Stops[id]
			if def then
				total += 1
				local been = seen[id] == true
				if been then
					got += 1
				end
				local rowFrame = Gui.frame(col, {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 40 + (j - 1) * 44),
					Size = UDim2.new(1, 0, 0, 40),
				})
				Gui.label(rowFrame, if been then def.name else "???", {
					Size = UDim2.new(1, -40, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = if been then INK else FAINT,
					MaxText = 24,
				})
				local dot = Gui.label(rowFrame, if been then "●" else "○", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, 36, 1, 0),
					TextColor3 = if been then STAMP else FAINT,
					MaxText = 30,
				})
				dot.Rotation = if been then -12 else 0
			end
		end
	end
	local header = gui:FindFirstChild("Count") :: TextLabel?
	if header then
		header.Text = `{got} of {total} stops ridden`
	end
end

local function attach(board: BasePart)
	if surface then
		surface:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RouteMapGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.4
	gui.ResetOnSpawn = false
	gui.Adornee = board
	gui.Parent = Gui.playerGui()
	surface = gui
	Gui.label(gui, "ROUTE 9N  ·  HOLLOW COUNTY TRANSIT", {
		Name = "Title",
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 50),
		Font = Gui.FontBold,
		TextColor3 = INK,
		MaxText = 46,
	})
	Gui.label(gui, "", {
		Name = "Count",
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 0, 34),
		TextColor3 = STAMP,
		MaxText = 28,
	})
	board.AncestryChanged:Connect(function()
		if not board:IsDescendantOf(workspace) and surface == gui then
			gui:Destroy()
			surface = nil
		end
	end)
	draw()
end

local function find()
	local lobby = workspace:FindFirstChild("Lobby")
	local depot = lobby and lobby:FindFirstChild("Depot")
	local board = depot and depot:FindFirstChild("RouteMap")
	if board and board:IsA("BasePart") then
		attach(board)
	end
end

function RouteMapController:Init() end

function RouteMapController:Start()
	player:GetAttributeChangedSignal("StopIds"):Connect(draw)
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 60)
		if not lobby then
			return -- a Route place has no depot
		end
		-- The board may stream in (and out) as the player moves around.
		lobby.DescendantAdded:Connect(function(d: Instance)
			if d.Name == "RouteMap" and d:IsA("BasePart") then
				attach(d)
			end
		end)
		find()
	end)
end

return RouteMapController
