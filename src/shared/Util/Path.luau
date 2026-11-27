--!strict
-- Path: an arc-length polyline of CFrames (the "spline" the bus follows).
-- Road chunks append dense points (every few studs) so linear interpolation is smooth.
-- Points far behind the bus can be trimmed; distances stay absolute.

export type Path = {
	points: { CFrame },
	dist: { number }, -- cumulative distance at each point
	append: (self: Path, points: { CFrame }) -> (),
	length: (self: Path) -> number,
	startDistance: (self: Path) -> number,
	sample: (self: Path, s: number) -> CFrame,
	trimBefore: (self: Path, s: number) -> (),
	last: (self: Path) -> CFrame?,
}

local Path = {}
Path.__index = Path

function Path.new(): Path
	return (setmetatable({ points = {}, dist = {} }, Path) :: any) :: Path
end

function Path.append(self: any, points: { CFrame })
	for _, cf in points do
		local n = #self.points
		if n == 0 then
			table.insert(self.points, cf)
			table.insert(self.dist, 0)
		else
			local gap = (cf.Position - self.points[n].Position).Magnitude
			if gap > 0.05 then
				table.insert(self.points, cf)
				table.insert(self.dist, self.dist[n] + gap)
			end
		end
	end
end

function Path.length(self: any): number
	local n = #self.dist
	return if n > 0 then self.dist[n] else 0
end

function Path.startDistance(self: any): number
	return self.dist[1] or 0
end

function Path.last(self: any): CFrame?
	return self.points[#self.points]
end

local function findSegment(dist: { number }, s: number): number
	-- Largest i with dist[i] <= s.
	local lo, hi = 1, #dist
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if dist[mid] <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

function Path.sample(self: any, s: number): CFrame
	local points, dist = self.points, self.dist
	local n = #points
	if n == 0 then
		return CFrame.identity
	end
	if s <= dist[1] then
		return points[1]
	end
	if s >= dist[n] then
		return points[n]
	end
	local i = findSegment(dist, s)
	local a, b = points[i], points[i + 1]
	local span = dist[i + 1] - dist[i]
	local t = if span > 0 then (s - dist[i]) / span else 0
	return a:Lerp(b, t)
end

-- Drop points that end before distance s (keeps one point before s).
function Path.trimBefore(self: any, s: number)
	local dist = self.dist
	local n = #dist
	if n < 3 then
		return
	end
	local i = findSegment(dist, s)
	if i > 2 then
		local keepFrom = i - 1
		local newPoints, newDist = {}, {}
		for j = keepFrom, n do
			table.insert(newPoints, self.points[j])
			table.insert(newDist, dist[j])
		end
		self.points = newPoints
		self.dist = newDist
	end
end

-- Helpers that make dense point lists for road shapes. All are relative to a start
-- CFrame whose LookVector is the direction of travel.

local STEP = 6

-- A straight run of `length` studs, rising `rise` studs on a smooth S-curve.
function Path.straight(start: CFrame, length: number, rise: number?): { CFrame }
	local out = {}
	local steps = math.max(1, math.ceil(length / STEP))
	local up = rise or 0
	for i = 0, steps do
		local t = i / steps
		local height = up * (1 - math.cos(t * math.pi)) / 2
		local pos = start * Vector3.new(0, height, -length * t)
		-- slope for the look direction
		local slope = up * math.pi * math.sin(t * math.pi) / (2 * length)
		local forward = (start.LookVector + start.UpVector * slope).Unit
		table.insert(out, CFrame.lookAt(pos, pos + forward, start.UpVector))
	end
	return out
end

-- A bump: up `height` studs and back down over `length` studs.
function Path.hill(start: CFrame, length: number, height: number): { CFrame }
	local out = {}
	local steps = math.max(1, math.ceil(length / STEP))
	for i = 0, steps do
		local t = i / steps
		local y = height * math.sin(t * math.pi) ^ 2
		local pos = start * Vector3.new(0, y, -length * t)
		local slope = height * 2 * math.sin(t * math.pi) * math.cos(t * math.pi) * math.pi / length
		local forward = (start.LookVector + start.UpVector * slope).Unit
		table.insert(out, CFrame.lookAt(pos, pos + forward, start.UpVector))
	end
	return out
end

-- An arc of `angle` radians (positive turns right) with the given radius.
function Path.arc(start: CFrame, radius: number, angle: number): { CFrame }
	local out = {}
	local arcLength = math.abs(angle) * radius
	local steps = math.max(1, math.ceil(arcLength / STEP))
	local side = if angle >= 0 then 1 else -1
	-- centre of the circle, to the right (+X) for right turns
	local centre = start * CFrame.new(side * radius, 0, 0)
	for i = 0, steps do
		local a = angle * (i / steps)
		-- rotate the start frame about the centre's up axis
		local rotated = centre * CFrame.Angles(0, -a, 0) * CFrame.new(-side * radius, 0, 0)
		local cf = CFrame.fromMatrix(rotated.Position, rotated.RightVector, rotated.UpVector)
		table.insert(out, cf)
	end
	return out
end

return Path
