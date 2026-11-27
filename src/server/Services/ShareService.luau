--!strict
-- Share prompts (plan, "Share prompts in the game"). At three clip-worthy moments the
-- server tells that player's client, which takes a screenshot with CaptureService and
-- offers to share it with an invite to the game:
--   returned  made it back to the bus after being Left Behind
--   mimic     escorted a mimic off
--   ending    any ending (not the First Ride)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local ShareService = {}

local function moment(player: Player, kind: string, ending: string?)
	if player.Parent then
		Net.notify(player, "ShareMoment", { kind = kind, ending = ending })
	end
end

function ShareService:Init() end

function ShareService:Start()
	local between = Registry.find("BetweenService")
	if between then
		between.Returned:Connect(function(player: Player)
			-- A beat later, once they're out of the fade.
			task.delay(1.5, moment, player, "returned")
		end)
	end
	local passengers = Registry.find("PassengerService")
	if passengers then
		passengers.Escorted:Connect(function(player: Player, wasMimic: boolean)
			if wasMimic then
				task.delay(1, moment, player, "mimic")
			end
		end)
	end
	local director = Registry.find("RunDirector")
	if director then
		director.RunEnded:Connect(function(ending: string)
			if ending == "Tutorial" then
				return
			end
			for _, player in director.runPlayers() do
				moment(player, "ending", ending)
			end
		end)
	end
end

return ShareService
