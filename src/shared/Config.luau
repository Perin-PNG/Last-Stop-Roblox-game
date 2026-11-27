--!strict
-- Game-wide constants. Keep tunable numbers here, not scattered in scripts.

local Config = {
	GameName = "My Game",
	MaxPlayers = 4,
	DebugLogging = true,
}

return table.freeze(Config)
