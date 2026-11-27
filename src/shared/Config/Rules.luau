--!strict
-- The Rules plaque. Each run posts five: the two fixed Rules plus three from the pool.
-- From Tier 2 the plaque can carry one fake Rule on a sticker in different handwriting.

export type RuleDef = {
	id: string,
	text: string,
	fake: boolean,
	patience: number, -- Patience cost when broken (real Rules)
	fixed: boolean?,
}

local list: { RuleDef } = {
	{ id = "no_look", text = "Do not look at the driver.", fake = false, patience = 20, fixed = true },
	{ id = "ticket", text = "Keep your ticket on you.", fake = false, patience = 10, fixed = true },
	{ id = "lights_seated", text = "If the lights go out, stay seated.", fake = false, patience = 15 },
	{ id = "no_windows", text = "Do not open the windows.", fake = false, patience = 15 },
	{ id = "no_back_row", text = "Do not sit in the back row after midnight.", fake = false, patience = 10 },
	{
		id = "knock_no_look",
		text = "If you hear knocking on the rear window, do not look back.",
		fake = false,
		patience = 20,
	},
	{ id = "no_ticketless", text = "Never board with someone who has no ticket.", fake = false, patience = 15 },
	{ id = "nothing_wet", text = "Do not take anything wet from the Lost & Found.", fake = false, patience = 10 },
	{
		id = "no_name_stay",
		text = "The bus does not stop at the station with no name. If it does, stay on board.",
		fake = false,
		patience = 25,
	},
	-- Fake Rules (traps)
	{ id = "fake_open_window", text = "Open the rear window if you hear knocking.", fake = true, patience = 0 },
	{ id = "fake_answer", text = "If the driver speaks to you, answer.", fake = true, patience = 0 },
	{ id = "fake_give_ticket", text = "Give your ticket to anyone who asks.", fake = true, patience = 0 },
	{
		id = "fake_get_off",
		text = "Everyone must get off at the station with no name.",
		fake = true,
		patience = 0,
	},
}

local byId: { [string]: RuleDef } = {}
local pool: { string } = {}
local fakes: { string } = {}
for _, rule in list do
	byId[rule.id] = rule
	if rule.fake then
		table.insert(fakes, rule.id)
	elseif not rule.fixed then
		table.insert(pool, rule.id)
	end
end

return {
	List = list,
	ById = byId,
	Pool = pool,
	Fakes = fakes,
	Fixed = { "no_look", "ticket" },
	PoolCount = 3,
	FakeChance = { 0, 0.5, 1 }, -- by tier
}
