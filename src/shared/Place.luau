--!strict
-- Which job this server has. Config.Products.Places holds the real PlaceIds; while they
-- are 0 (or in Studio) the game runs "Combined": the lobby and the run share one server,
-- so a Studio playtest can do everything.

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

export type Role = "Lobby" | "Route" | "Combined"

local Place = {}

function Place.role(): Role
	local places = Config.Products.Places
	if RunService:IsStudio() or places.Lobby == 0 or places.Route == 0 then
		return "Combined"
	end
	if game.PlaceId == places.Route then
		return "Route"
	end
	return "Lobby"
end

function Place.hasLobby(): boolean
	return Place.role() ~= "Route"
end

function Place.hasRun(): boolean
	return Place.role() ~= "Lobby"
end

return Place
