--!strict
-- All game config in one place. Tunable numbers live in Tuning; content lives in the
-- other modules. Nothing here is secret: clients can read all of it.

local Tuning = require(script.Tuning)
local Items = require(script.Items)
local Stops = require(script.Stops)
local Anomalies = require(script.Anomalies)
local Rules = require(script.Rules)
local Passengers = require(script.Passengers)
local Entities = require(script.Entities)
local Meta = require(script.Meta)
local Products = require(script.Products)
local Audio = require(script.Audio)
local Text = require(script.Text)

local Config = {
	GameName = "Don't Look at the Driver",
	StoreName = "Don't Look at the Driver [Co-op Horror]",
	Authority = "Hollow County Transit Authority",
	Route = 'Route 9N "Night Owl"',
	Version = "0.5.0",
	DebugLogging = true,
	Tuning = Tuning,
	Items = Items,
	Stops = Stops,
	Anomalies = Anomalies,
	Rules = Rules,
	Passengers = Passengers,
	Entities = Entities,
	Meta = Meta,
	Products = Products,
	Audio = Audio,
	Text = Text,
}

return Config
