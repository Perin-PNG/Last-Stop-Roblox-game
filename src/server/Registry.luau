--!strict
-- The server's service list. Main requires each service in this order, calls Init on all of
-- them, then Start on all of them. Services find each other with Registry.get in Init, which
-- avoids circular requires.

local Registry = {}

-- Order matters only for Init (things that must exist before others Init).
Registry.Order = {
	"WorldService",
	"DataService",
	"AnalyticsHooks",
	"PlayerStateService",
	"InventoryService",
	"NoiseService",
	"GazeService",
	"DreadService",
	"ChunkService",
	"BusService",
	"DriverService",
	"CabinService",
	"RouteService",
	"RulesService",
	"StopService",
	"AnomalyService",
	"PassengerService",
	"RideEventService",
	"EntityService",
	"LatecomerService",
	"BetweenService",
	"PingService",
	"PhotoService",
	"GhostService",
	"RewardService",
	"JournalService",
	"MonetizationService",
	"BadgeService",
	"FinaleService",
	"RunDirector",
	"MatchmakingService",
	"LobbyService",
	"KioskService",
	"CosmeticService",
	"DebugService",
}

local services: { [string]: any } = {}

function Registry.add(name: string, service: any)
	services[name] = service
end

function Registry.get(name: string): any
	local service = services[name]
	assert(service, "Unknown service " .. name)
	return service
end

function Registry.find(name: string): any?
	return services[name]
end

function Registry.all(): { [string]: any }
	return services
end

return Registry
