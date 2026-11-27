--!strict
-- A plain roadside stop: shelter, streetlights, a small closed shop and a trailhead.
-- Used for the M0 drive test and for any stop id that has no builder yet.

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage:WaitForChild("Shared").Util.Build)

local C = Build.Colors

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.basics(refs, title, 90, -60, 60)
	local shop = StopKit.building(refs, "Shop", Vector3.new(50, 6.5, -20), Vector3.new(28, 13, 34), C.Brick, 6, -20)
	local _ = shop
	StopKit.ceilingLight(refs, Vector3.new(50, 12, -20))
	for i = 1, 6 do
		StopKit.lootPoint(refs, Vector3.new(44 + (i % 3) * 5, 1.5, -30 + i * 3))
	end
	StopKit.fragmentSite(refs, Vector3.new(60, 1.5, -32))
	StopKit.trailhead(refs, CFrame.new(96, 0, 40))
	StopKit.backEntrance(refs, CFrame.new(96, 3, -50))
	StopKit.entitySpawn(refs, CFrame.new(80, 3, 30))
	return refs
end
