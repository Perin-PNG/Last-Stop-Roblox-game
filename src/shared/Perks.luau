--!strict
-- Which Perks a player has equipped. DataService (server) sets the Perk and Perk2 Player
-- attributes; both sides read them through this so the second Perk slot always counts.

local Perks = {}

function Perks.has(player: Player, id: string): boolean
	return player:GetAttribute("Perk") == id or player:GetAttribute("Perk2") == id
end

return Perks
