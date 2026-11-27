--!strict
-- Hides every interaction prompt while this player is Down or Static (the server ignores
-- their triggers anyway), so the screen doesn't offer things they can't do.

local ProximityPromptService = game:GetService("ProximityPromptService")

local Client = script.Parent.Parent
local State = require(Client:WaitForChild("State"))

local PromptController = {}

function PromptController:Start()
	State.watchMine("State", function(state: any)
		ProximityPromptService.Enabled = state ~= "Downed" and state ~= "Static"
	end)
end

return PromptController
