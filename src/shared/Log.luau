--!strict
-- Tagged logging so Claude can find its own messages in the Output log
-- (get_console_output) during playtests.

local Config = require(script.Parent.Config)

local Log = {}

function Log.info(tag: string, ...: any)
	if Config.DebugLogging then
		print(`[{tag}]`, ...)
	end
end

function Log.warn(tag: string, ...: any)
	warn(`[{tag}]`, ...)
end

return Log
