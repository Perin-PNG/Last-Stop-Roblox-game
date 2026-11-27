--!strict
-- Passes, developer products and private servers. Dormant until Perin creates each item in
-- Creator Hub and pastes its id into Config.Products: an id of 0 is never offered, never
-- checked and never granted. Prices come from MarketplaceService, never from code.
--
-- Developer products are idempotent: ProcessReceipt grants the item, records the
-- PurchaseId in the player's data, saves, and only then returns PurchaseGranted. A
-- repeated receipt is recognised and not granted twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Products = Config.Products

local MonetizationService = {}

local Data: any

-- Pass key -> the player attribute it sets.
local PASS_ATTRIBUTES = {
	CommuterPass = "CommuterPass",
	LiveryPack = "LiveryPack",
	VoicePackDispatch = "VoicePackDispatch",
	PolaroidFrames = "PolaroidFrames",
}

local function passKeyFor(id: number): string?
	if id == 0 then
		return nil
	end
	for key, passId in Products.Passes :: any do
		if passId == id then
			return key
		end
	end
	return nil
end

local function checkPasses(player: Player)
	for key, id in Products.Passes :: any do
		if type(id) == "number" and id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and owns then
				player:SetAttribute(PASS_ATTRIBUTES[key] or key, true)
			end
		end
	end
end

-- What a developer product does. Returns false if it can't be granted yet.
local function grant(player: Player, key: string): boolean
	local def = (Products.Products :: any)[key]
	if not def then
		return false
	end
	if def.tokens then
		Data.addTokens(player, def.tokens, "purchase")
		Net.notify(player, "Toast", { text = `+{def.tokens} Tokens. Thank you!` })
		return true
	elseif key == "RunDoubler" then
		local rewards = Registry.find("RewardService")
		local last = if rewards then rewards.lastPayout[player] else nil
		local amount = if type(last) == "number" and last > 0 then last else 200
		if rewards then
			rewards.lastPayout[player] = nil
		end
		Data.addTokens(player, amount, "doubler")
		Net.notify(player, "Toast", { text = `Run doubled: +{amount} Tokens.` })
		return true
	elseif key == "TipTheDriver" then
		Net.notifyAll("Sound", { key = "Horn" })
		Net.notifyAll("Toast", { text = `{player.DisplayName} tipped the Driver. The horn sounds, twice.` })
		return true
	end
	return false
end

local function productKeyFor(id: number): string?
	if id == 0 then
		return nil
	end
	for key, def in Products.Products :: any do
		if type(def) == "table" and def.id == id then
			return key
		end
	end
	return nil
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Data.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if data.purchases[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted
	end
	local key = productKeyFor(info.ProductId)
	if not key then
		Log.warn("Shop", "Unknown product", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grant, player, key)
	if not ok or not granted then
		Log.warn("Shop", "Grant failed", key, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Data.update(player, function(d: any)
		d.purchases[purchaseId] = os.time()
	end)
	if not Data.saveNow(player) then
		-- The grant is in the session; Roblox will retry the receipt, and the PurchaseId
		-- stops a second grant once the save lands.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Log.info("Shop", player.Name, "bought", key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Is this a paid private Lobby server? Runs from it are private runs.
function MonetizationService.isPrivate(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

function MonetizationService:Init()
	Data = Registry.get("DataService")
end

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, id: number, bought: boolean)
		local key = passKeyFor(id)
		if bought and key then
			player:SetAttribute(PASS_ATTRIBUTES[key] or key, true)
			Net.notify(player, "Toast", { text = "Thank you! Your pass is active." })
		end
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(checkPasses, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPasses, player)
	end
	local World = Registry.find("WorldService")
	if World then
		World.RunState:SetAttribute("PrivateServer", MonetizationService.isPrivate())
	end
end

return MonetizationService
