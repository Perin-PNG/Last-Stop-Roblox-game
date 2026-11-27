--!strict
-- Seeded random helpers. Every random roll in a run goes through one of these so a
-- seed replays the same run (Daily Route, debugging).

export type Rng = {
	seed: number,
	int: (self: Rng, min: number, max: number) -> number,
	float: (self: Rng, min: number?, max: number?) -> number,
	chance: (self: Rng, p: number) -> boolean,
	pick: <T>(self: Rng, list: { T }) -> T,
	shuffle: <T>(self: Rng, list: { T }) -> { T },
	weighted: (self: Rng, weights: { [string]: number }) -> string,
	sample: <T>(self: Rng, list: { T }, count: number) -> { T },
	child: (self: Rng, salt: string) -> Rng,
}

local Seed = {}
Seed.__index = Seed

local function hashString(s: string): number
	-- FNV-1a, 32-bit.
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return h
end

function Seed.new(seed: number): Rng
	local self = setmetatable({
		seed = seed,
		_random = Random.new(seed),
	}, Seed)
	return (self :: any) :: Rng
end

-- A number that changes every UTC day, for the Daily Route seed.
function Seed.daily(time: number?): number
	local day = os.date("!*t", time or os.time())
	return hashString(string.format("daily-%04d-%02d-%02d", day.year, day.month, day.day))
end

function Seed.fresh(): number
	return Random.new():NextInteger(1, 2 ^ 30)
end

Seed.hash = hashString

function Seed.int(self: any, min: number, max: number): number
	if max < min then
		return min
	end
	return self._random:NextInteger(min, max)
end

function Seed.float(self: any, min: number?, max: number?): number
	local lo = min or 0
	local hi = max or 1
	return lo + self._random:NextNumber() * (hi - lo)
end

function Seed.chance(self: any, p: number): boolean
	return self._random:NextNumber() < p
end

function Seed.pick(self: any, list: { any }): any
	return list[self._random:NextInteger(1, math.max(1, #list))]
end

function Seed.shuffle(self: any, list: { any }): { any }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = self._random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

function Seed.sample(self: any, list: { any }, count: number): { any }
	local shuffled = self:shuffle(list)
	local out = {}
	for i = 1, math.min(count, #shuffled) do
		out[i] = shuffled[i]
	end
	return out
end

function Seed.weighted(self: any, weights: { [string]: number }): string
	local keys = {}
	local total = 0
	for key, weight in weights do
		if weight > 0 then
			table.insert(keys, key)
			total += weight
		end
	end
	table.sort(keys) -- stable order so the same seed gives the same pick
	local roll = self._random:NextNumber() * total
	for _, key in keys do
		roll -= weights[key]
		if roll <= 0 then
			return key
		end
	end
	return keys[#keys]
end

-- A new generator derived from this seed and a label, so systems don't consume each
-- other's random numbers (adding a passenger roll doesn't change which stops appear).
function Seed.child(self: any, salt: string): Rng
	return Seed.new((self.seed + hashString(salt)) % 2147483647)
end

return Seed
