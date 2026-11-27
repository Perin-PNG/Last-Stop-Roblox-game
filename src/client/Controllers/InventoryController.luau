--!strict
-- The four shared slots and the flashlight. The server owns the inventory and mirrors it
-- onto player attributes (Inventory = "battery,fuel,+,"; "+" is the second half of a
-- two-slot item). This sends what the player wants to do with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local State = require(Client:WaitForChild("State"))
local Registry = require(Client:WaitForChild("Registry"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))

local InventoryController = {}

local SLOTS = 4

-- The current slots as item ids ("" empty, "+" continuation).
function InventoryController.slots(): { string }
	local raw = State.mine("Inventory")
	local out = table.create(SLOTS, "")
	if type(raw) == "string" then
		local n = 0
		for part in string.gmatch(raw .. ",", "([^,]*),") do
			n += 1
			if n <= SLOTS then
				out[n] = part
			end
		end
	end
	return out
end

function InventoryController.selected(): number
	local s = State.mine("Slot")
	return if type(s) == "number" then math.clamp(s, 1, SLOTS) else 1
end

-- The slot holding the start of the item in `slot` (a "+" belongs to the slot before it).
local function head(slots: { string }, slot: number): number
	while slot > 1 and slots[slot] == "+" do
		slot -= 1
	end
	return slot
end

function InventoryController.selectedItem(): string?
	local slots = InventoryController.slots()
	local id = slots[head(slots, InventoryController.selected())]
	return if id ~= "" and id ~= "+" then id else nil
end

function InventoryController.select(slot: number)
	slot = math.clamp(slot, 1, SLOTS)
	Net.event("SelectSlot"):FireServer(slot)
end

local function cycle(step: number)
	local slots = InventoryController.slots()
	local current = InventoryController.selected()
	for i = 1, SLOTS do
		local n = ((current - 1 + step * i) % SLOTS) + 1
		if slots[n] ~= "+" then
			InventoryController.select(n)
			return
		end
	end
end

local function canAct(): boolean
	local state = State.mine("State")
	return state == "Aboard" or state == "Outside" or state == "LeftBehind"
end

function InventoryController:Start()
	local Input = Registry.get("InputController")
	for n = 1, SLOTS do
		Input.on("Slot" .. n, function()
			InventoryController.select(n)
		end)
	end
	Input.on("SlotNext", function()
		cycle(1)
	end)
	Input.on("SlotPrev", function()
		cycle(-1)
	end)
	Input.on("Use", function()
		if not canAct() or not InventoryController.selectedItem() then
			return
		end
		local slots = InventoryController.slots()
		Net.event("UseItem"):FireServer(head(slots, InventoryController.selected()))
	end)
	Input.on("Throw", function()
		local id = InventoryController.selectedItem()
		if not canAct() or not id then
			return
		end
		local def = Config.Items[id]
		local camera = workspace.CurrentCamera
		if not def or not def.throwable or not camera then
			return
		end
		local slots = InventoryController.slots()
		Net.event("ThrowItem"):FireServer(head(slots, InventoryController.selected()), camera.CFrame.LookVector)
	end)
	Input.on("Drop", function()
		if not InventoryController.selectedItem() then
			return
		end
		local slots = InventoryController.slots()
		Net.event("DropItem"):FireServer(head(slots, InventoryController.selected()))
	end)
	Input.on("Flashlight", function()
		if not canAct() then
			return
		end
		Net.event("Flashlight"):FireServer(State.mine("Light") ~= true)
	end)
	-- Touch: only show THROW when holding something throwable.
	local function refreshTouch()
		local id = InventoryController.selectedItem()
		local def = id and Config.Items[id]
		Input.setTouchVisible("Throw", def ~= nil and def.throwable == true)
		Input.setTouchVisible("Use", id ~= nil)
	end
	State.watchMine("Inventory", refreshTouch)
	State.watchMine("Slot", refreshTouch)
end

return InventoryController
