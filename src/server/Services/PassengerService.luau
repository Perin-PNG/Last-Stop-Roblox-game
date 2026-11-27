--!strict
-- Passengers and mimics. Some stops have someone waiting at the curb. They board when the
-- doors close unless a player tells them to wait for the next bus. Regulars ride one to
-- three stops and leave a gift (an item, transfers or a true hint). Mimics look like
-- regulars, carry two tells each, and act at the next Blackout, when a player is alone
-- with them in the back half of the bus for 10 seconds, or (Tier 3) on a random roll.
--
-- Tells and where they show:
--   no_reflection   no reflection in the bus windows (client, NoReflection attribute)
--   photo_blurred   the face is smeared in a Polaroid photo (PhotoService asks us)
--   ticket_tomorrow its ticket is dated tomorrow (Ask for ticket)
--   never_blinks    it never blinks (client, NeverBlinks attribute)
--   echoes_ping     it answers with your last ping-wheel line, word for word
--   knows_name      it greets you by display name
--   wrong_shadow    its shadow falls toward the light
--   false_hint      its hint about this stop is false
-- The mirror always shows a mimic's true shape (client, TrueShape attribute).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local Seed = require(Shared.Util.Seed)
local Signal = require(Shared.Util.Signal)
local Build = require(Shared.Util.Build)

local Server = script.Parent.Parent
local Registry = require(Server:WaitForChild("Registry"))
local PassengerRig = require(Server:WaitForChild("Builders"):WaitForChild("PassengerRig"))

local Defs = Config.Passengers
local Tuning = Config.Tuning.Passengers
local StopTuning = Config.Tuning.Stop
local Anomalies = Config.Anomalies

local PassengerService = {}

PassengerService.Escorted = Signal.new() :: Signal.Signal<Player, boolean> -- (player, wasMimic)
PassengerService.Acted = Signal.new() :: Signal.Signal<string, Player?> -- (kind: "down" | "steal", target)
PassengerService.Recovered = Signal.new() :: Signal.Signal<Player> -- (player) won a stolen fragment back

type Passenger = {
	key: number,
	def: any,
	mimic: boolean,
	doppel: Player?,
	tells: { [string]: boolean },
	state: string, -- Waiting | Aboard | Off | Revealed | Carrying
	model: Model?,
	seat: Seat?,
	stopsLeft: number,
	told: boolean,
	carrying: boolean,
	alone: { [Player]: number },
	connections: { RBXScriptConnection },
}

local passengers: { Passenger } = {}
local nextKey = 0
local rng = Seed.new(1)
local lastPing: { [Player]: string } = {}

local PlayerState: any
local Bus: any
local Driver: any
local Inventory: any
local Run: any
local Pings: any
local RunState: Folder
local folder: Folder

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- Helpers ------------------------------------------------------------------------------

local function head(p: Passenger): BasePart?
	local m = p.model
	return if m then m:FindFirstChild("Head") :: BasePart? else nil
end

local function say(p: Passenger, text: string)
	local h = head(p)
	if h then
		Net.notifyAll("Bubble", { part = h, text = text, name = p.def.name })
	end
end

local function aboardPlayers(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if PlayerState.isHealthy(player) and Bus.isAboard(player) then
			table.insert(out, player)
		end
	end
	return out
end

local function phase(): string
	return (RunState:GetAttribute("Phase") :: string?) or "Idle"
end

local function refs(): any
	return Bus.refs
end

local function removeModel(p: Passenger)
	if p.seat then
		p.seat.Disabled = false
		p.seat:SetAttribute("Passenger", nil)
		p.seat = nil
	end
	if p.model then
		p.model:Destroy()
		p.model = nil
	end
	for _, c in p.connections do
		c:Disconnect()
	end
	table.clear(p.connections)
end

local function drop(p: Passenger)
	removeModel(p)
	local i = table.find(passengers, p)
	if i then
		table.remove(passengers, i)
	end
end

local function clearAll()
	for _, p in table.clone(passengers) do
		drop(p)
	end
	table.clear(passengers)
end

-- Bus geometry, from the Interior part: the aisle runs along its long axis, and the half
-- away from the driver's seat is the back half.
local function busLocal(pos: Vector3): (Vector3?, boolean)
	local r = refs()
	if not r or not r.interior then
		return nil, false
	end
	local interior: BasePart = r.interior
	local cf = interior.CFrame
	local localPos = cf:PointToObjectSpace(pos)
	local longZ = interior.Size.Z >= interior.Size.X
	local driverLocal = cf:PointToObjectSpace(r.driverSeat.Position)
	local along = if longZ then localPos.Z else localPos.X
	local driverAlong = if longZ then driverLocal.Z else driverLocal.X
	return localPos, along * driverAlong < 0
end

local function inBackHalf(pos: Vector3): boolean
	local _, back = busLocal(pos)
	return back
end

-- The world direction from a point toward the aisle's centre line.
local function towardAisle(pos: Vector3): Vector3
	local r = refs()
	if not r or not r.interior then
		return Vector3.zero
	end
	local interior: BasePart = r.interior
	local cf = interior.CFrame
	local localPos = cf:PointToObjectSpace(pos)
	local longZ = interior.Size.Z >= interior.Size.X
	local v = if longZ then Vector3.new(-math.sign(localPos.X), 0, 0) else Vector3.new(0, 0, -math.sign(localPos.Z))
	return cf:VectorToWorldSpace(v)
end

local function freeSeat(): Seat?
	local r = refs()
	if not r then
		return nil
	end
	local free: { Seat } = {}
	for _, seat in r.seats :: { Seat } do
		if seat.Parent and seat.Occupant == nil and not seat.Disabled and seat.Transparency < 1 then
			table.insert(free, seat)
		end
	end
	if #free == 0 then
		return nil
	end
	return free[rng:int(1, #free)]
end

-- The shadow blob: under the seat, away from the aisle lights, or (wrong_shadow) out in
-- the aisle, toward them.
local function placeShadow(p: Passenger)
	local m = p.model
	local blob = m and m:FindFirstChild("ShadowBlob") :: BasePart?
	if not m or not blob then
		return
	end
	local toAisle = towardAisle(blob.Position)
	local shift = if p.tells.wrong_shadow then toAisle * 2.4 else -toAisle * 0.6
	blob.CFrame = blob.CFrame + shift
end

local function standingShadow(p: Passenger, streetlights: { BasePart }?)
	local m = p.model
	local blob = m and m:FindFirstChild("ShadowBlob") :: BasePart?
	if not m or not blob or not streetlights or #streetlights == 0 then
		return
	end
	local nearest: BasePart? = nil
	for _, light in streetlights do
		if not nearest or (light.Position - blob.Position).Magnitude < (nearest.Position - blob.Position).Magnitude then
			nearest = light
		end
	end
	if not nearest then
		return
	end
	local flat = (nearest.Position - blob.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 then
		return
	end
	local dir = flat.Unit
	local base = (m.PrimaryPart :: BasePart).Position * Vector3.new(1, 0, 1) + Vector3.new(0, blob.Position.Y, 0)
	local away = if p.tells.wrong_shadow then dir else -dir
	blob.CFrame = CFrame.new(base + away * 1.6) * blob.CFrame.Rotation
end

local function tagModel(p: Passenger)
	local m = p.model
	if not m then
		return
	end
	m:SetAttribute("PassengerKey", p.key)
	m:SetAttribute("PassengerName", p.def.name)
	m:SetAttribute("NeverBlinks", p.tells.never_blinks == true)
	m:SetAttribute("NoReflection", p.tells.no_reflection == true)
	m:SetAttribute("TrueShape", p.mimic)
	if p.doppel then
		local gui = Instance.new("BillboardGui")
		gui.Name = "NameTag"
		gui.Size = UDim2.fromOffset(200, 24)
		gui.StudsOffset = Vector3.new(0, 1.8, 0)
		gui.MaxDistance = 60
		gui.Adornee = m:FindFirstChild("Head") :: any
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 16
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.6
		label.Text = p.doppel.DisplayName
		label.Parent = gui
		gui.Parent = m
	end
end

-- What a passenger looks like: its def's outfit, or for a doppel, a player's colours.
local function lookOf(p: Passenger): PassengerRig.Look
	local d = p.def
	local look: PassengerRig.Look = { skin = d.skin, shirt = d.shirt, pants = d.pants, hat = d.hat, prop = d.prop }
	local target = p.doppel
	if target and target.Character then
		local colors = target.Character:FindFirstChildWhichIsA("BodyColors")
		if colors then
			look.skin = colors.HeadColor3
			look.shirt = colors.TorsoColor3
			look.pants = colors.LeftLegColor3
		end
		look.hat = nil
		look.prop = nil
	end
	return look
end

-- Lines ------------------------------------------------------------------------------

local function lineFor(p: Passenger, to: Player?): string
	if p.mimic and p.tells.echoes_ping and to and lastPing[to] then
		return lastPing[to]
	end
	if p.mimic and p.tells.knows_name and to then
		return string.format(Defs.MimicLines[1], to.DisplayName)
	end
	if p.mimic and rng:chance(0.5) then
		-- Close, but wrong. Skip the line that needs a name.
		return Defs.MimicLines[rng:int(2, #Defs.MimicLines)]
	end
	return rng:pick(p.def.lines)
end

local function humanize(slot: string): string
	return (string.gsub(slot, "_", " "))
end

-- A hint about the stop the bus is at: true from regulars, false from false_hint mimics.
local function hintFor(built: any, truthful: boolean): string
	local ids: { string } = built and built.anomalies or {}
	local slotNames: { string } = {}
	if built and built.refs then
		for name in built.refs.slots do
			table.insert(slotNames, name)
		end
	end
	local wrongSlots: { [string]: boolean } = {}
	for _, id in ids do
		local def = Anomalies.ById[id]
		if def then
			wrongSlots[def.slot] = true
		end
	end
	if truthful then
		for _, id in ids do
			local def = Anomalies.ById[id]
			if def and def.slot then
				return `Watch the {humanize(def.slot)} here. Something about it isn't right.`
			end
		end
		return "This one's quiet tonight. Nothing's changed here."
	end
	if #ids > 0 and rng:chance(0.5) then
		return "This one's quiet tonight. Nothing's changed here."
	end
	local fine: { string } = {}
	for _, name in slotNames do
		if not wrongSlots[name] then
			table.insert(fine, name)
		end
	end
	if #fine > 0 then
		return `Watch the {humanize(rng:pick(fine))} here. Something about it isn't right.`
	end
	return "This one's quiet tonight. Nothing's changed here."
end

local function ticketText(p: Passenger): string
	local t = os.time() + (if p.tells.ticket_tomorrow then 86400 else 0)
	local date = os.date("!*t", t)
	return `{p.def.name}'s ticket: Route 9N, Hollow County Transit. Valid {MONTHS[date.month]} {date.day} only.`
end

-- Prompts ----------------------------------------------------------------------------

local escort: (p: Passenger, player: Player) -> ()

local function askTicket(p: Passenger, player: Player)
	if not PlayerState.isHealthy(player) then
		return
	end
	Net.notify(player, "Toast", { text = ticketText(p) })
	say(p, lineFor(p, player))
end

local function addPrompts(p: Passenger, waiting: boolean)
	local m = p.model
	local torso = m and m.PrimaryPart
	if not m or not torso then
		return
	end
	local ticket = Build.prompt(torso, "Ask for ticket", p.def.name, 0, 8, "TicketPrompt")
	table.insert(
		p.connections,
		ticket.Triggered:Connect(function(player: Player)
			askTicket(p, player)
		end)
	)
	if waiting then
		local wait = Build.prompt(torso, "Tell them to wait for the next bus", p.def.name, 1, 10, "WaitPrompt")
		wait.KeyboardKeyCode = Enum.KeyCode.F
		wait.GamepadKeyCode = Enum.KeyCode.ButtonY
		table.insert(
			p.connections,
			wait.Triggered:Connect(function(player: Player)
				if p.state ~= "Waiting" or p.told or not PlayerState.isHealthy(player) then
					return
				end
				p.told = true
				wait.Enabled = false
				say(p, if p.mimic then "You'll see me again." else "Next one, then. Sure.")
				Log.info("Passengers", player.Name, "told", p.def.name, "to wait", if p.mimic then "(mimic)" else "")
			end)
		)
	else
		local out = Build.prompt(torso, "Escort off", p.def.name, Tuning.EscortHoldSeconds, 8, "EscortPrompt")
		out.KeyboardKeyCode = Enum.KeyCode.F
		out.GamepadKeyCode = Enum.KeyCode.ButtonY
		out.Enabled = phase() == "Stop"
		table.insert(
			p.connections,
			RunState:GetAttributeChangedSignal("Phase"):Connect(function()
				out.Enabled = phase() == "Stop" and p.state == "Aboard"
			end)
		)
		table.insert(
			p.connections,
			out.Triggered:Connect(function(player: Player)
				if p.state ~= "Aboard" or phase() ~= "Stop" then
					return
				end
				if not PlayerState.isHealthy(player) or not Bus.isAboard(player) then
					return
				end
				escort(p, player)
			end)
		)
	end
end

-- Spawning and boarding -------------------------------------------------------------------

local function pickDef(tier: number): any
	local pool = {}
	for _, def in Defs.Regulars do
		if (def.minTier or 1) <= tier then
			local taken = false
			for _, p in passengers do
				if p.def.id == def.id and def.recurring then
					taken = true
				end
			end
			if not taken then
				table.insert(pool, def)
			end
		end
	end
	if #pool == 0 then
		return Defs.Regulars[1]
	end
	return rng:pick(pool)
end

local function rollTells(): { [string]: boolean }
	local tells: { [string]: boolean } = {}
	for _, tell in rng:sample(Defs.Tells, 2) do
		tells[tell] = true
	end
	return tells
end

local function floorAtCurb(built: any, offset: Vector3?): CFrame
	local spot: BasePart = built.refs.passengerSpot
	local frame: CFrame = built.refs.frame
	local at = (frame:Inverse() * spot.CFrame).Position + (offset or Vector3.zero)
	return frame * CFrame.new(at.X, 0.4, at.Z) * CFrame.Angles(0, math.rad(90), 0)
end

local function spawnWaiting(built: any)
	local tier = math.clamp(built.tier or 1, 1, 3)
	local overtime = (RunState:GetAttribute("Overtime") :: number?) or 0
	local mimicShare = if overtime > 0 then Tuning.OvertimeMimicShare else Tuning.MimicShare[tier]
	nextKey += 1
	local mimic = rng:chance(mimicShare)
	local def = pickDef(tier)
	local doppel: Player? = nil
	if mimic and tier >= 3 and rng:chance(Tuning.DoppelChance) then
		local candidates = aboardPlayers()
		if #candidates > 0 then
			doppel = rng:pick(candidates)
		end
	end
	local p: Passenger = {
		key = nextKey,
		def = if doppel then { id = "doppel", name = doppel.DisplayName, lines = def.lines, gifts = {} } else def,
		mimic = mimic,
		doppel = doppel,
		tells = if mimic then rollTells() else {},
		state = "Waiting",
		model = nil,
		seat = nil,
		stopsLeft = rng:int(Tuning.RideStops[1], Tuning.RideStops[2]),
		told = false,
		carrying = false,
		alone = {},
		connections = {},
	}
	if doppel then
		-- A doppel's look comes from the player it copies; keep the outfit table it needs.
		p.def.skin, p.def.shirt, p.def.pants = def.skin, def.shirt, def.pants
	end
	local floor = floorAtCurb(built)
	p.model = PassengerRig.standing(folder, "Passenger_" .. p.def.name, floor, lookOf(p))
	tagModel(p)
	standingShadow(p, built.refs.streetlights)
	addPrompts(p, true)
	table.insert(passengers, p)
	Net.notifyAll("Hint", { id = "first_passenger" })
	task.delay(2, function()
		if p.state == "Waiting" then
			say(p, lineFor(p, nil))
		end
	end)
	Log.info(
		"Passengers",
		"waiting at",
		built.id,
		p.def.name,
		if mimic then "MIMIC" else "regular",
		if doppel then "(doppel)" else ""
	)
end

local function board(p: Passenger)
	local seat = freeSeat()
	if not seat then
		drop(p)
		return
	end
	removeModel(p)
	p.state = "Aboard"
	p.seat = seat
	seat.Disabled = true
	seat:SetAttribute("Passenger", p.key)
	p.model = PassengerRig.seated(refs().model, "Passenger_" .. p.def.name, seat, lookOf(p))
	tagModel(p)
	placeShadow(p)
	PassengerRig.attach(p.model :: Model, seat)
	addPrompts(p, false)
	Log.info("Passengers", p.def.name, "boarded", if p.mimic then "(mimic)" else "")
end

-- Getting off, gifts and hints --------------------------------------------------------

local function walkAway(p: Passenger, built: any)
	removeModel(p)
	p.state = "Off"
	local floor = floorAtCurb(built, Vector3.new(4, 0, 0)) * CFrame.Angles(0, math.rad(180), 0)
	p.model = PassengerRig.standing(folder, "Passenger_" .. p.def.name, floor, lookOf(p))
	tagModel(p)
	-- Walk off into the lot and fade out.
	local m = p.model :: Model
	task.spawn(function()
		local start = m:GetPivot()
		for step = 1, 40 do
			if not m.Parent then
				return
			end
			m:PivotTo(start * CFrame.new(0, 0, step * -0.6))
			task.wait(0.1)
		end
		drop(p)
	end)
end

local function giveGift(p: Passenger, built: any)
	local gifts = p.def.gifts
	if not gifts or next(gifts) == nil or not p.seat then
		return
	end
	local gift = rng:weighted(gifts)
	local seatTop = p.seat.CFrame * CFrame.new(0, p.seat.Size.Y / 2, 0)
	if gift == "hint" then
		local text = hintFor(built, true)
		say(p, text)
		Net.notifyList(aboardPlayers(), "Toast", { text = `{p.def.name}: "{text}"` })
	elseif gift == "transfers" then
		Inventory.spawnItem("transfers", seatTop, nil, rng:int(2, 4))
		say(p, "For the fare. You'll need it more than me.")
	else
		Inventory.spawnItem(gift, seatTop)
		say(p, "Here. Take this. I won't need it.")
	end
end

local function getOff(p: Passenger, built: any)
	if not p.mimic then
		giveGift(p, built)
	else
		say(p, "This is me. For now.")
	end
	walkAway(p, built)
end

-- A mimic carrying a banked fragment gets off at the trailhead. Catch it to win it back.
local function fleeToTrailhead(p: Passenger, built: any)
	removeModel(p)
	p.state = "Carrying"
	local trail: BasePart = built.refs.trailhead
	local frame: CFrame = built.refs.frame
	local at = frame:PointToObjectSpace(trail.Position)
	local floor = frame * CFrame.new(at.X, 0.4, at.Z) * CFrame.Angles(0, math.rad(-90), 0)
	p.model = PassengerRig.trueShape(folder, "Mimic", floor)
	local m = p.model :: Model
	local frag = Build.part(m, {
		name = "StolenFragment",
		size = Vector3.new(0.9, 0.1, 1.2),
		cf = (m.PrimaryPart :: BasePart).CFrame * CFrame.new(0, 1, -1),
		color = Color3.fromRGB(255, 240, 200),
		material = Enum.Material.Neon,
		collide = false,
	})
	local prompt = Build.prompt(m.PrimaryPart :: BasePart, "Take it back", "Route fragment", 1.5, 9, "TakeBack")
	table.insert(
		p.connections,
		prompt.Triggered:Connect(function(player: Player)
			if p.state ~= "Carrying" or not PlayerState.isHealthy(player) then
				return
			end
			p.state = "Off"
			local cf = frag.CFrame
			if not Inventory.give(player, "fragment") then
				Inventory.spawnItem("fragment", cf)
			end
			Net.notifyAll("Sound", { key = "SoftSting", at = cf.Position })
			Net.notifyAll("Toast", { text = `{player.DisplayName} took the fragment back.` })
			PassengerService.Recovered:Fire(player)
			drop(p)
		end)
	)
end

-- Mimics ----------------------------------------------------------------------------

local function nearestTo(pos: Vector3, list: { Player }): Player?
	local best: Player? = nil
	local bestDist = math.huge
	for _, player in list do
		local root = PlayerState.rootOf(player)
		if root then
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best
end

-- Stand up revealed in the aisle beside its seat, riding along with the bus.
local function revealAboard(p: Passenger): Model?
	local seat = p.seat
	local r = refs()
	if not seat or not r then
		return nil
	end
	local base = seat.Position + towardAisle(seat.Position) * 2.4
	local floorY = r.interior.Position.Y - r.interior.Size.Y / 2
	local look = towardAisle(seat.Position)
	removeModel(p)
	local floor = CFrame.lookAt(Vector3.new(base.X, floorY, base.Z), Vector3.new(base.X, floorY, base.Z) - look)
	p.model = PassengerRig.trueShape(r.model, "Mimic", floor)
	PassengerRig.attach(p.model :: Model, r.root)
	return p.model
end

function PassengerService.act(p: Passenger, target: Player?, reason: string)
	if p.state ~= "Aboard" or not p.mimic then
		return
	end
	local pos = if p.model and p.model.PrimaryPart then p.model.PrimaryPart.Position else nil
	if not pos then
		return
	end
	local victims = aboardPlayers()
	local fragments = (RunState:GetAttribute("Fragments") :: number?) or 0
	local steal = fragments > 0 and rng:chance(0.5)
	p.state = "Revealed"
	revealAboard(p)
	Net.notifyAll("Sound", { key = "Sting", at = pos })
	Log.info("Passengers", "mimic acts:", reason, if steal then "steal" else "down")
	if steal then
		RunState:SetAttribute("Fragments", fragments - 1)
		p.carrying = true
		Net.notifyAll("Toast", { text = "Something took a fragment off the route board." })
		PassengerService.Acted:Fire("steal", nil)
		return
	end
	local victim = target or nearestTo(pos, victims)
	if victim then
		PlayerState.down(victim, "mimic")
	end
	PassengerService.Acted:Fire("down", victim)
	task.delay(2.5, function()
		if (p.state :: string) == "Revealed" and not p.carrying then
			drop(p)
		end
	end)
end

-- Every mimic aboard acts (a Blackout).
function PassengerService.actAll(reason: string)
	for _, p in table.clone(passengers) do
		if p.mimic and p.state == "Aboard" then
			PassengerService.act(p, nil, reason)
		end
	end
end

-- Escort off: a regular walks away (costs Patience and its gift); a mimic reveals itself
-- on the curb and goes for the escort.
escort = function(p: Passenger, player: Player)
	local built = Run.current
	if not built or not built.refs then
		return
	end
	removeModel(p)
	PassengerService.Escorted:Fire(player, p.mimic)
	if not p.mimic then
		Driver.change(-Config.Tuning.Patience.EscortRegular, "escorted a passenger", player)
		walkAway(p, built)
		say(p, "Fine. I'll walk.")
		return
	end
	p.state = "Revealed"
	local floor = floorAtCurb(built)
	p.model = PassengerRig.trueShape(folder, "Mimic", floor)
	local m = p.model :: Model
	Net.notifyAll("Sound", { key = "Sting", at = floor.Position })
	Log.info("Passengers", player.Name, "escorted a mimic off")
	task.spawn(function()
		task.wait(0.8)
		local started = os.clock()
		while m.Parent and os.clock() - started < 10 do
			if not PlayerState.isHealthy(player) or Bus.isAboard(player) then
				break
			end
			local root = PlayerState.rootOf(player)
			if not root then
				break
			end
			local here = m:GetPivot().Position
			local to = (root.Position - here) * Vector3.new(1, 0, 1)
			if to.Magnitude < 3 then
				PlayerState.down(player, "mimic")
				PassengerService.Acted:Fire("down", player)
				break
			end
			local step = math.min(to.Magnitude, 22 * 0.1)
			local nextPos = here + to.Unit * step
			m:PivotTo(CFrame.lookAt(nextPos, nextPos + to.Unit))
			task.wait(0.1)
		end
	end)
end

-- The alone trigger: one player by themselves in the back half with a mimic for 10 s.
local function aloneTick(dt: number)
	local ph = phase()
	if ph ~= "Ride" and ph ~= "Arriving" and ph ~= "Departing" and ph ~= "Stop" then
		return
	end
	local back: { Player } = {}
	for _, player in aboardPlayers() do
		local root = PlayerState.rootOf(player)
		if root and inBackHalf(root.Position) then
			table.insert(back, player)
		end
	end
	for _, p in table.clone(passengers) do
		if p.mimic and p.state == "Aboard" and p.seat and inBackHalf(p.seat.Position) then
			if #back == 1 then
				local player = back[1]
				p.alone[player] = (p.alone[player] or 0) + dt
				for other in p.alone do
					if other ~= player then
						p.alone[other] = nil
					end
				end
				if p.alone[player] >= Tuning.AloneTriggerSeconds then
					PassengerService.act(p, player, "alone")
				end
			else
				table.clear(p.alone)
			end
		end
	end
end

-- Idle chatter on rides, so passengers feel like people.
local function chatter()
	if phase() ~= "Ride" then
		return
	end
	for _, p in passengers do
		if p.state == "Aboard" and rng:chance(0.12) then
			local riders = aboardPlayers()
			local to = if p.mimic and p.tells.knows_name and #riders > 0 then rng:pick(riders) else nil
			say(p, lineFor(p, to))
		end
	end
end

-- Run flow ----------------------------------------------------------------------------

local function onStopOpened(built: any)
	if not built or not built.refs then
		return
	end
	-- Passengers already aboard: count down their stops, maybe offer a hint.
	for _, p in table.clone(passengers) do
		if p.state == "Aboard" then
			p.stopsLeft -= 1
			local hints = if p.mimic then p.tells.false_hint == true else (p.def.gifts and p.def.gifts.hint) ~= nil
			if p.stopsLeft > 0 and hints and not built.terminal and rng:chance(0.5) then
				task.delay(3, function()
					if p.state == "Aboard" then
						say(p, hintFor(built, not p.mimic))
					end
				end)
			end
			if p.stopsLeft <= 0 or built.terminal then
				getOff(p, built)
			end
		elseif p.state == "Revealed" and p.carrying then
			fleeToTrailhead(p, built)
		end
	end
	if built.terminal then
		return
	end
	local aboard = 0
	for _, p in passengers do
		if p.state == "Aboard" or p.state == "Waiting" then
			aboard += 1
		end
	end
	if aboard >= Tuning.MaxAboard then
		return
	end
	local tier = math.clamp(built.tier or 1, 1, 3)
	local overtime = (RunState:GetAttribute("Overtime") :: number?) or 0
	local chance = if overtime > 0 then StopTuning.OvertimePassengerChance else StopTuning.PassengerChance[tier]
	if rng:chance(chance) then
		spawnWaiting(built)
	end
end

local function onStopClosed()
	for _, p in table.clone(passengers) do
		if p.state == "Waiting" then
			if p.told then
				drop(p)
			else
				board(p)
			end
		elseif p.state == "Off" or p.state == "Carrying" or (p.state == "Revealed" and not p.carrying) then
			-- Left on the curb (escorted, got off, or a mimic that never caught anyone), or
			-- the fragment thief got away with it.
			if p.state == "Carrying" then
				Net.notifyAll("Toast", { text = "The fragment is gone with it." })
			end
			drop(p)
		end
	end
end

local function onRideStarted(index: number)
	if index <= 1 then
		return
	end
	local tier = (RunState:GetAttribute("Tier") :: number?) or 1
	if tier < 3 then
		return
	end
	for _, p in passengers do
		if p.mimic and p.state == "Aboard" and rng:chance(Tuning.RandomActChancePerRide) then
			task.delay(rng:float(12, 30), function()
				if p.state == "Aboard" and phase() == "Ride" then
					PassengerService.act(p, nil, "random")
				end
			end)
		end
	end
end

-- API used by PhotoService and the Inspector -------------------------------------------

function PassengerService.list(): { Passenger }
	return passengers
end

-- The passenger a model belongs to, if any.
function PassengerService.fromModel(m: Instance): any?
	for _, p in passengers do
		if p.model and (m == p.model or m:IsDescendantOf(p.model)) then
			return p
		end
	end
	return nil
end

function PassengerService.photoBlurred(p: any): boolean
	return p.mimic and p.tells.photo_blurred == true
end

function PassengerService:Init()
	PlayerState = Registry.get("PlayerStateService")
	Bus = Registry.get("BusService")
	Driver = Registry.get("DriverService")
	Inventory = Registry.get("InventoryService")
	Run = Registry.get("RunDirector")
	Pings = Registry.find("PingService")
	local world = Registry.get("WorldService")
	RunState = world.RunState
	folder = world.Folders.Passengers
end

function PassengerService:Start()
	Run.RunStarted:Connect(function()
		clearAll()
		rng = Seed.new(Run.seed):child("passengers")
		table.clear(lastPing)
	end)
	Run.RunEnded:Connect(clearAll)
	Run.StopOpened:Connect(onStopOpened)
	Run.StopClosed:Connect(onStopClosed)
	Run.RideStarted:Connect(onRideStarted)
	Bus.Spawned:Connect(function()
		-- A new bus: whoever sat in the old one is gone.
		for _, p in table.clone(passengers) do
			if p.state == "Aboard" or p.state == "Revealed" then
				drop(p)
			end
		end
	end)
	RunState:GetAttributeChangedSignal("Blackout"):Connect(function()
		if RunState:GetAttribute("Blackout") == true then
			PassengerService.actAll("blackout")
		end
	end)
	if Pings then
		Pings.Pinged:Connect(function(player: Player, id: number)
			local def = Config.Text.Pings[id]
			if not def then
				return
			end
			lastPing[player] = def.text
			if not Bus.isAboard(player) then
				return
			end
			for _, p in passengers do
				if p.mimic and p.tells.echoes_ping and p.state == "Aboard" then
					task.delay(1.6, function()
						if p.state == "Aboard" then
							say(p, def.text)
						end
					end)
				end
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPing[player] = nil
		for _, p in passengers do
			p.alone[player] = nil
		end
	end)
	task.spawn(function()
		local sinceChatter = 0
		while true do
			local dt = task.wait(0.5)
			local ok, err = pcall(function()
				aloneTick(dt)
				sinceChatter += dt
				if sinceChatter >= 15 then
					sinceChatter = 0
					chatter()
				end
			end)
			if not ok then
				Log.warn("Passengers", "tick failed", err)
			end
		end
	end)
end

return PassengerService
