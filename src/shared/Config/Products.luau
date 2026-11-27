--!strict
-- Places, badges and Robux products. Every id is 0 until Perin creates the item in
-- Creator Hub and pastes its id here. Anything with id 0 is hidden in the game.
-- Prices always come from MarketplaceService at runtime, never from this file.

return {
	Places = {
		Lobby = 0, -- the start place
		Route = 0, -- the run place (reserved servers only)
	},
	GroupId = 0, -- the Hollow County Transit Authority Roblox group, for the join reward
	Badges = {
		FirstRide = 0,
		Home = 0,
		Transfer = 0,
		LastStop = 0,
		DriversSeat = 0,
		BackFromTheBetween = 0,
		EyesFront = 0,
		NotOnMyBus = 0,
		LateFee = 0,
		Inspector = 0,
		Lifer = 0,
	},
	Passes = {
		CommuterPass = 0, -- +25% Tokens forever and an exclusive jacket
		LiveryPack = 0, -- three bus liveries
		VoicePackDispatch = 0, -- alternate ping voice lines
		PolaroidFrames = 0,
	},
	Products = {
		Tokens500 = { id = 0, tokens = 500 },
		Tokens1400 = { id = 0, tokens = 1400 },
		Tokens3000 = { id = 0, tokens = 3000 },
		RunDoubler = { id = 0 }, -- also the rewarded video ad reward
		TipTheDriver = { id = 0 },
	},
	RewardedAdsEnabled = false,
}
