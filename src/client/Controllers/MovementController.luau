--!strict
-- Sprint and crouch. Sprint is held on keyboard and gamepad and toggles on touch; crouch
-- always toggles. The server decides the real speed (stamina, heavy items, carrying);
-- the client only says what the player wants.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local State = require(Client:WaitForChild("State"))
local Registry = require(Client:WaitForChild("Registry"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local MovementController = {}

local sprinting = false
local crouching = false
local sent = ""

local function send()
	local want = if crouching then "crouch" elseif sprinting then "sprint" else "walk"
	if want ~= sent then
		sent = want
		Net.event("Move"):FireServer(want)
	end
end

function MovementController.stop()
	sprinting = false
	crouching = false
	send()
end

function MovementController:Start()
	local Input = Registry.get("InputController")
	local Settings = Registry.get("SettingsController")
	local function toggleSprint(): boolean
		return Input.isTouch() or Settings.get("sprintToggle") == true
	end
	Input.on("Sprint", function()
		if toggleSprint() then
			sprinting = not sprinting
		else
			sprinting = true
		end
		if sprinting then
			crouching = false
		end
		send()
	end, function()
		if not toggleSprint() then
			sprinting = false
			send()
		end
	end)
	Input.on("Crouch", function()
		crouching = not crouching
		if crouching then
			sprinting = false
		end
		send()
	end)
	-- Out of stamina: the server drops the sprint; follow it so the toggle doesn't stick.
	State.watchMine("Stamina", function(value: any)
		if sprinting and type(value) == "number" and value <= 0 then
			sprinting = false
			send()
		end
	end)
	State.watchMine("State", function()
		MovementController.stop()
	end)
	-- Show which mode a touch toggle is in.
	State.watchMine("Stance", function(stance: any)
		for name, on in { Sprint = stance == "Sprint", Crouch = stance == "Crouch" } do
			local b = Input.touchButton(name)
			if b then
				b.BackgroundColor3 = if on then Color3.fromRGB(150, 110, 40) else Color3.fromRGB(20, 20, 26)
			end
		end
	end)
end

return MovementController
