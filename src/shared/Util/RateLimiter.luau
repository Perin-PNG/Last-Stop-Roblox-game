--!strict
-- Token bucket rate limiter, one bucket per key (usually a player).

export type Limiter = {
	allow: (self: Limiter, key: any) -> boolean,
	forget: (self: Limiter, key: any) -> (),
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

-- rate: tokens per second; burst: bucket size.
function RateLimiter.new(rate: number, burst: number): Limiter
	return (
		setmetatable({
			rate = rate,
			burst = burst,
			buckets = {} :: { [any]: { tokens: number, last: number } },
		}, RateLimiter) :: any
	) :: Limiter
end

function RateLimiter.allow(self: any, key: any): boolean
	local now = os.clock()
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.burst, last = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.burst, bucket.tokens + (now - bucket.last) * self.rate)
	bucket.last = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.forget(self: any, key: any)
	self.buckets[key] = nil
end

return RateLimiter
