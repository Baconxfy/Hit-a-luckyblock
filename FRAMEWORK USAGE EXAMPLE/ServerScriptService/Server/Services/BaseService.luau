local Framework: any = require(game:GetService("ReplicatedStorage").Framework :: ModuleScript)

local Players = game:GetService('Players')

local BaseService = Framework:CreateService("BaseService")

local DEFAULT_FRIDGE_DATA_KEY = 'Fridge'
local DEFAULT_MAX_BULK_UPGRADES = 1000

local function roundToNearest(value: number, nearest: number): number
	nearest = math.max(1, tonumber(nearest) or 1)
	return math.floor((value / nearest) + 0.5) * nearest
end

local function getFridgeConfig()
	return Framework.Config.Fridge or {}
end

local function getMicrowaveConfig()
	return Framework.Config.Microwave or {}
end

local function getMicrowaveUpgradeConfig()
	return getMicrowaveConfig().Upgrade or {}
end

local function getMicrowaveShopEntry(microwaveId: string?)
	local shop = getMicrowaveConfig().Shop
	if type(shop) ~= 'table' then
		return nil
	end

	for _, entry in ipairs(shop) do
		if type(entry) == 'table' and tostring(entry.Id) == tostring(microwaveId) then
			return entry
		end
	end
	return nil
end

local function getUpgradeCount(data): number
	return math.max(0, math.floor(tonumber(data and data.UpgradeCount) or 0))
end

local function getUpgradesPerLevel(): number
	return math.max(1, math.floor(tonumber(getFridgeConfig().UpgradesPerLevel) or 10))
end

local function getFridgeLevel(upgradeCount: number): number
	return math.floor(upgradeCount / getUpgradesPerLevel()) + 1
end

local function isMilestoneUpgrade(nextUpgradeCount: number): boolean
	return nextUpgradeCount % getUpgradesPerLevel() == 0
end

local function getMutationChance(mutationPoints: number): number
	local mutationConfig = getFridgeConfig().Mutation or {}
	local maxChance = tonumber(mutationConfig.MaxChance) or 0.65
	local scalingRate = tonumber(mutationConfig.ScalingRate) or 0.045
	return maxChance * (1 - math.exp(-math.max(0, mutationPoints) * scalingRate))
end

local function getUpgradeReward(upgradeCount: number)
	local nextUpgradeCount = upgradeCount + 1
	local fridgeLevel = getFridgeLevel(upgradeCount)
	local pumpConfig = getFridgeConfig().PumpPower or {}
	local mutationConfig = getFridgeConfig().Mutation or {}
	local smallGain = math.max(
		1,
		math.floor((tonumber(pumpConfig.BaseSmallGain) or 1) * (fridgeLevel ^ (tonumber(pumpConfig.SmallGainLevelPower) or 0.75)))
	)
	local milestone = isMilestoneUpgrade(nextUpgradeCount)
	local mutationPointGain = 0

	if milestone then
		local newFridgeLevel = getFridgeLevel(nextUpgradeCount)
		mutationPointGain += math.max(0, math.floor(tonumber(mutationConfig.MilestonePointGain) or 1))
		local bonusEvery = math.max(0, math.floor(tonumber(mutationConfig.BonusPointEveryLevels) or 0))
		if bonusEvery > 0 and newFridgeLevel % bonusEvery == 0 then
			mutationPointGain += math.max(0, math.floor(tonumber(mutationConfig.BonusPointAmount) or 0))
		end
	end

	return {
		IsMilestone = milestone,
		PumpPowerGain = if milestone then smallGain * (tonumber(pumpConfig.MilestoneGainMultiplier) or 10) else smallGain,
		MutationPointGain = mutationPointGain,
	}
end

local function getUpgradeCost(upgradeCount: number): number
	local costConfig = getFridgeConfig().Cost or {}
	local baseCost = tonumber(costConfig.BaseCost) or 100
	local growthRate = tonumber(costConfig.GrowthRate) or 1.13
	local cost = baseCost * (growthRate ^ upgradeCount)
	if isMilestoneUpgrade(upgradeCount + 1) then
		cost *= tonumber(costConfig.MilestoneMultiplier) or 3
	end
	return math.max(0, roundToNearest(cost, tonumber(costConfig.RoundToNearest) or 5))
end

local function getMicrowaveUpgradesPerLevel(): number
	return math.max(1, math.floor(tonumber(getMicrowaveUpgradeConfig().UpgradesPerLevel) or 10))
end

local function getMicrowaveUpgradeCount(data): number
	return math.max(0, math.floor(tonumber(data and data.UpgradeCount) or 0))
end

local function getMicrowaveLevel(upgradeCount: number): number
	return math.floor(upgradeCount / getMicrowaveUpgradesPerLevel()) + 1
end

local function isMicrowaveMilestoneUpgrade(nextUpgradeCount: number): boolean
	return nextUpgradeCount % getMicrowaveUpgradesPerLevel() == 0
end

local function getMicrowaveUpgradeReward(upgradeCount: number)
	local nextUpgradeCount = upgradeCount + 1
	local microwaveLevel = getMicrowaveLevel(upgradeCount)
	local config = getMicrowaveUpgradeConfig()
	local luckConfig = config.Luck or {}
	local mutationConfig = config.Mutation or {}
	local cookSpeedConfig = config.CookSpeed or {}
	local smallLuckGain = (tonumber(luckConfig.BaseSmallGain) or 0.2)
		* (microwaveLevel ^ (tonumber(luckConfig.SmallGainLevelPower) or 0.55))
	local milestone = isMicrowaveMilestoneUpgrade(nextUpgradeCount)
	local mutationGain = 0
	local cookSpeedGain = 0

	if milestone then
		local newLevel = getMicrowaveLevel(nextUpgradeCount)
		mutationGain += tonumber(mutationConfig.MilestoneGain) or 0.5
		cookSpeedGain += tonumber(cookSpeedConfig.MilestoneGain) or 0.05

		local mutationBonusEvery = math.max(0, math.floor(tonumber(mutationConfig.BonusGainEveryLevels) or 0))
		if mutationBonusEvery > 0 and newLevel % mutationBonusEvery == 0 then
			mutationGain += tonumber(mutationConfig.BonusGainAmount) or 0
		end

		local cookBonusEvery = math.max(0, math.floor(tonumber(cookSpeedConfig.BonusGainEveryLevels) or 0))
		if cookBonusEvery > 0 and newLevel % cookBonusEvery == 0 then
			cookSpeedGain += tonumber(cookSpeedConfig.BonusGainAmount) or 0
		end
	end

	return {
		IsMilestone = milestone,
		LuckGain = if milestone then smallLuckGain * (tonumber(luckConfig.MilestoneGainMultiplier) or 5) else smallLuckGain,
		MutationLuckGain = mutationGain,
		CookSpeedGain = cookSpeedGain,
	}
end

local function getMicrowaveUpgradeCost(upgradeCount: number): number
	local costConfig = getMicrowaveUpgradeConfig().Cost or {}
	local baseCost = tonumber(costConfig.BaseCost) or 250
	local growthRate = tonumber(costConfig.GrowthRate) or 1.14
	local cost = baseCost * (growthRate ^ upgradeCount)
	if isMicrowaveMilestoneUpgrade(upgradeCount + 1) then
		cost *= tonumber(costConfig.MilestoneMultiplier) or 3
	end
	return math.max(0, roundToNearest(cost, tonumber(costConfig.RoundToNearest) or 5))
end

local function getMicrowaveBaseStats(microwaveId: string)
	local entry = getMicrowaveShopEntry(microwaveId) or {}
	return {
		LuckBonus = tonumber(entry.BaseLuckBonus) or 0,
		MutationLuckBonus = tonumber(entry.BaseMutationLuckBonus) or 0,
		CookSpeed = math.max(0.1, tonumber(entry.BaseCookSpeed) or 1),
	}
end

local function getMicrowaveBulkUpgradeQuote(data, cash: number, requestedAmount: any)
	local maxBulk = math.max(1, math.floor(tonumber(getMicrowaveUpgradeConfig().MaxBulkUpgrades) or DEFAULT_MAX_BULK_UPGRADES))
	local amount = if requestedAmount == 'Max' then maxBulk else math.floor(tonumber(requestedAmount) or 1)
	if amount < 1 then
		amount = 1
	end
	amount = math.min(amount, maxBulk)

	local startUpgradeCount = getMicrowaveUpgradeCount(data)
	local upgradeCount = startUpgradeCount
	local luckGain = 0
	local mutationLuckGain = 0
	local cookSpeedGain = 0
	local totalCost = 0
	local quotedAmount = 0

	for _ = 1, amount do
		local cost = getMicrowaveUpgradeCost(upgradeCount)
		if requestedAmount == 'Max' and totalCost + cost > cash then
			break
		end

		local reward = getMicrowaveUpgradeReward(upgradeCount)
		totalCost += cost
		luckGain += reward.LuckGain
		mutationLuckGain += reward.MutationLuckGain
		cookSpeedGain += reward.CookSpeedGain
		upgradeCount += 1
		quotedAmount += 1
	end

	if requestedAmount == 'Max' and quotedAmount == 0 then
		local cost = getMicrowaveUpgradeCost(startUpgradeCount)
		local reward = getMicrowaveUpgradeReward(startUpgradeCount)
		totalCost = cost
		luckGain = reward.LuckGain
		mutationLuckGain = reward.MutationLuckGain
		cookSpeedGain = reward.CookSpeedGain
		upgradeCount = startUpgradeCount + 1
	end

	return {
		Amount = math.max(1, quotedAmount),
		ActualAffordableAmount = quotedAmount,
		TotalCost = totalCost,
		LuckGain = luckGain,
		MutationLuckGain = mutationLuckGain,
		CookSpeedGain = cookSpeedGain,
		FinalUpgradeCount = upgradeCount,
		IsMilestone = getMicrowaveLevel(upgradeCount) > getMicrowaveLevel(startUpgradeCount),
	}
end

local function getBulkUpgradeQuote(data, cash: number, requestedAmount: any)
	local maxBulk = math.max(1, math.floor(tonumber(getFridgeConfig().MaxBulkUpgrades) or DEFAULT_MAX_BULK_UPGRADES))
	local amount = if requestedAmount == 'Max' then maxBulk else math.floor(tonumber(requestedAmount) or 1)
	if amount < 1 then
		amount = 1
	end
	amount = math.min(amount, maxBulk)

	local startUpgradeCount = getUpgradeCount(data)
	local upgradeCount = startUpgradeCount
	local pumpPowerGain = 0
	local mutationPointGain = 0
	local totalCost = 0
	local quotedAmount = 0

	for _ = 1, amount do
		local cost = getUpgradeCost(upgradeCount)
		if requestedAmount == 'Max' and totalCost + cost > cash then
			break
		end

		local reward = getUpgradeReward(upgradeCount)
		totalCost += cost
		pumpPowerGain += reward.PumpPowerGain
		mutationPointGain += reward.MutationPointGain
		upgradeCount += 1
		quotedAmount += 1
	end

	if requestedAmount == 'Max' and quotedAmount == 0 then
		local cost = getUpgradeCost(startUpgradeCount)
		local reward = getUpgradeReward(startUpgradeCount)
		totalCost = cost
		pumpPowerGain = reward.PumpPowerGain
		mutationPointGain = reward.MutationPointGain
		upgradeCount = startUpgradeCount + 1
	end

	return {
		Amount = math.max(1, quotedAmount),
		ActualAffordableAmount = quotedAmount,
		TotalCost = totalCost,
		PumpPowerGain = pumpPowerGain,
		MutationPointGain = mutationPointGain,
		FinalUpgradeCount = upgradeCount,
		IsMilestone = getFridgeLevel(upgradeCount) > getFridgeLevel(startUpgradeCount),
	}
end

function BaseService:Initialize()
	self.Bases = {}
end

function BaseService:Start()
	self:SetupBases()

	Players.PlayerAdded:Connect(function(player)
		self:AssignBaseForPlayerWhenReady(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:AssignBaseForPlayerWhenReady(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local base = self:GetBaseFromPlayer(player)
		if base then base:Unclaim() end
	end)
end

function BaseService:AssignBaseForPlayerWhenReady(player: Player)
	task.spawn(function()
		local dataService = Framework:GetService('DataService')
		local profile = dataService:GetProfileAsync(player.UserId)
		if not profile then
			return
		end
		if player.Parent == Players and self:GetBaseFromPlayer(player) == nil then
			self:AssignBaseForPlayer(player)
		end
	end)
end

function BaseService:AssignBaseForPlayer(player)
	local base = self:GetVacantBase()
	if base then
		self:NormalizePlayerStage(player, base)
		base:Claim(player)
		player.RespawnLocation = base.SpawnLocation
	end
end

function BaseService:GetPadsConfig()
	return (Framework.Config and Framework.Config.Pads) or {}
end

function BaseService:GetBaseConfig()
	return (Framework.Config and Framework.Config.Base) or {}
end

function BaseService:GetBaseStageDataKey(): string
	return self:GetBaseConfig().StageDataKey or 'BaseStage'
end

function BaseService:GetDefaultStage(): number
	return tonumber(self:GetBaseConfig().DefaultStage) or 1
end

function BaseService:GetStageConfig(stage: number)
	local config = self:GetBaseConfig()
	return config.Stages and config.Stages[stage] or nil
end

function BaseService:GetNextStage(stage: number): number?
	local nextStage = stage + 1
	return if self:GetStageConfig(nextStage) then nextStage else nil
end

function BaseService:GetPlayerStage(player: Player): number
	local dataService = Framework:GetService('DataService')
	local stage = dataService:GetData(player.UserId, self:GetBaseStageDataKey())
	if type(stage) ~= 'number' or not self:GetStageConfig(stage) then
		stage = self:GetDefaultStage()
		dataService:UpdatePlayerData(player.UserId, self:GetBaseStageDataKey(), stage)
	end
	return math.floor(stage)
end

function BaseService:SetPlayerStage(player: Player, stage: number)
	local dataService = Framework:GetService('DataService')
	local value = math.max(1, math.floor(stage))
	if not self:GetStageConfig(value) then
		return false
	end
	return dataService:UpdatePlayerData(player.UserId, self:GetBaseStageDataKey(), value)
end

function BaseService:GetPadUnlockDataKey(): string
	return self:GetPadsConfig().UnlockedDataKey or 'PadsUnlocked'
end

function BaseService:GetFridgeDataKey(): string
	return (getFridgeConfig().DataKey or DEFAULT_FRIDGE_DATA_KEY)
end

function BaseService:GetFridgeData(player: Player)
	local dataService = Framework:GetService('DataService')
	local key = self:GetFridgeDataKey()
	local data = dataService:GetData(player.UserId, key)
	if type(data) ~= 'table' then
		data = {}
	end

	local upgradeCount = getUpgradeCount(data)
	local pumpPower = math.max(1, math.floor(tonumber(data.PumpPower) or 1))
	local mutationPoints = math.max(0, math.floor(tonumber(data.MutationPoints) or 0))
	local normalized = {
		UpgradeCount = upgradeCount,
		PumpPower = pumpPower,
		MutationPoints = mutationPoints,
	}

	if data.UpgradeCount ~= normalized.UpgradeCount or data.PumpPower ~= normalized.PumpPower or data.MutationPoints ~= normalized.MutationPoints then
		dataService:UpdatePlayerData(player.UserId, key, normalized)
	end

	return normalized
end

function BaseService:SaveFridgeData(player: Player, data): boolean
	return Framework:GetService('DataService'):UpdatePlayerData(player.UserId, self:GetFridgeDataKey(), {
		UpgradeCount = getUpgradeCount(data),
		PumpPower = math.max(1, math.floor(tonumber(data and data.PumpPower) or 1)),
		MutationPoints = math.max(0, math.floor(tonumber(data and data.MutationPoints) or 0)),
	})
end

function BaseService:GetFridgeUpgradeState(player: Player, requestedAmount: any?)
	local base = self:GetBaseFromPlayer(player)
	if not base then
		return {
			Ok = false,
			Reason = 'NoBase',
		}
	end

	local data = self:GetFridgeData(player)
	local reward = getUpgradeReward(data.UpgradeCount)
	local cash = tonumber(Framework:GetService('DataService'):GetData(player.UserId, 'Cash')) or 0
	local quote = getBulkUpgradeQuote(data, cash, requestedAmount or 1)
	local nextPumpPower = data.PumpPower + quote.PumpPowerGain
	local nextMutationPoints = data.MutationPoints + quote.MutationPointGain

	return {
		Ok = true,
		UpgradeCount = data.UpgradeCount,
		FridgeLevel = getFridgeLevel(data.UpgradeCount),
		NextFridgeLevel = getFridgeLevel(quote.FinalUpgradeCount),
		UpgradesPerLevel = getUpgradesPerLevel(),
		LevelProgress = (data.UpgradeCount % getUpgradesPerLevel()) / getUpgradesPerLevel(),
		NextLevelProgress = (quote.FinalUpgradeCount % getUpgradesPerLevel()) / getUpgradesPerLevel(),
		PumpPower = data.PumpPower,
		MutationPoints = data.MutationPoints,
		MutationChance = getMutationChance(data.MutationPoints),
		NextPumpPower = nextPumpPower,
		NextMutationPoints = nextMutationPoints,
		NextMutationChance = getMutationChance(nextMutationPoints),
		PumpPowerGain = reward.PumpPowerGain,
		MutationPointGain = reward.MutationPointGain,
		IsMilestone = reward.IsMilestone,
		BulkPumpPowerGain = quote.PumpPowerGain,
		BulkMutationPointGain = quote.MutationPointGain,
		BulkIsMilestone = quote.IsMilestone,
		RequestedAmount = requestedAmount or 1,
		PurchaseAmount = quote.Amount,
		AffordablePurchaseAmount = quote.ActualAffordableAmount,
		NextPrice = quote.TotalCost,
		SinglePrice = getUpgradeCost(data.UpgradeCount),
		CanAfford = cash >= quote.TotalCost and quote.ActualAffordableAmount > 0,
		Cash = cash,
	}
end

function BaseService:RefreshFridgeUpgrade(player: Player)
	local state = self:GetFridgeUpgradeState(player)
	local base = self:GetBaseFromPlayer(player)
	if base and base.UpdateFridgeUpgradeDisplay then
		base:UpdateFridgeUpgradeDisplay(state)
	end
	Framework:GetController('BaseController').Server.Fire:FridgeUpgradeChanged(player, state)
	return state
end

function BaseService:BuyFridgeUpgrade(player: Player, requestedAmount: any?)
	local state = self:GetFridgeUpgradeState(player, requestedAmount)
	if not state.Ok or not state.NextPrice then
		return state
	end

	if state.Cash < state.NextPrice or (tonumber(state.AffordablePurchaseAmount) or 0) <= 0 then
		state.Reason = 'NotEnoughCash'
		return state
	end

	local dataService = Framework:GetService('DataService')
	if not dataService:AddPlayerData(player.UserId, 'Cash', -state.NextPrice) then
		state.Ok = false
		state.Reason = 'SpendFailed'
		return state
	end

	local data = self:GetFridgeData(player)
	for _ = 1, math.max(1, math.floor(tonumber(state.PurchaseAmount) or 1)) do
		local reward = getUpgradeReward(data.UpgradeCount)
		data.UpgradeCount += 1
		data.PumpPower += reward.PumpPowerGain
		data.MutationPoints += reward.MutationPointGain
	end

	if not self:SaveFridgeData(player, data) then
		dataService:AddPlayerData(player.UserId, 'Cash', state.NextPrice)
		state.Ok = false
		state.Reason = 'SaveFailed'
		return state
	end

	self:RefreshFridgeUpgrade(player)
	return self:GetFridgeUpgradeState(player, requestedAmount)
end

function BaseService:GetMicrowaveUpgradeDataKey(): string
	return getMicrowaveConfig().UpgradeDataKey or 'MicrowaveUpgrades'
end

function BaseService:GetEquippedMicrowaveId(player: Player): string
	local config = getMicrowaveConfig()
	local dataService = Framework:GetService('DataService')
	local equipped = dataService:GetData(player.UserId, config.EquippedDataKey or 'EquippedMicrowave')
	return tostring(equipped or config.DefaultMicrowaveId or 'DefaultMicrowave')
end

function BaseService:GetMicrowaveUpgradeData(player: Player, microwaveId: string?)
	local dataService = Framework:GetService('DataService')
	local key = self:GetMicrowaveUpgradeDataKey()
	local allData = dataService:GetData(player.UserId, key)
	if type(allData) ~= 'table' then
		allData = {}
	end

	local id = tostring(microwaveId or self:GetEquippedMicrowaveId(player))
	local data = allData[id]
	if type(data) ~= 'table' then
		data = {}
	end

	local normalized = {
		UpgradeCount = getMicrowaveUpgradeCount(data),
		LuckBonus = math.max(0, tonumber(data.LuckBonus) or 0),
		MutationLuckBonus = math.max(0, tonumber(data.MutationLuckBonus) or 0),
		CookSpeedBonus = math.max(0, tonumber(data.CookSpeedBonus) or 0),
	}

	if
		type(allData[id]) ~= 'table'
		or data.UpgradeCount ~= normalized.UpgradeCount
		or data.LuckBonus ~= normalized.LuckBonus
		or data.MutationLuckBonus ~= normalized.MutationLuckBonus
		or data.CookSpeedBonus ~= normalized.CookSpeedBonus
	then
		allData[id] = normalized
		dataService:UpdatePlayerData(player.UserId, key, allData)
	end

	return normalized, id, allData
end

function BaseService:SaveMicrowaveUpgradeData(player: Player, microwaveId: string, data, allData): boolean
	local key = self:GetMicrowaveUpgradeDataKey()
	local saved = type(allData) == 'table' and allData or {}
	saved[microwaveId] = {
		UpgradeCount = getMicrowaveUpgradeCount(data),
		LuckBonus = math.max(0, tonumber(data and data.LuckBonus) or 0),
		MutationLuckBonus = math.max(0, tonumber(data and data.MutationLuckBonus) or 0),
		CookSpeedBonus = math.max(0, tonumber(data and data.CookSpeedBonus) or 0),
	}
	return Framework:GetService('DataService'):UpdatePlayerData(player.UserId, key, saved)
end

function BaseService:GetMicrowaveRuntimeStats(player: Player, microwaveId: string?)
	local id = tostring(microwaveId or self:GetEquippedMicrowaveId(player))
	local baseStats = getMicrowaveBaseStats(id)
	local data = self:GetMicrowaveUpgradeData(player, id)
	local maxCookSpeed = tonumber((getMicrowaveUpgradeConfig().CookSpeed or {}).Max) or 3

	return {
		MicrowaveId = id,
		LuckBonus = baseStats.LuckBonus + (tonumber(data.LuckBonus) or 0),
		MutationLuckBonus = baseStats.MutationLuckBonus + (tonumber(data.MutationLuckBonus) or 0),
		CookSpeed = math.clamp(baseStats.CookSpeed + (tonumber(data.CookSpeedBonus) or 0), 0.1, maxCookSpeed),
		BaseLuckBonus = baseStats.LuckBonus,
		BaseMutationLuckBonus = baseStats.MutationLuckBonus,
		BaseCookSpeed = baseStats.CookSpeed,
	}
end

function BaseService:GetMicrowaveUpgradeState(player: Player, requestedAmount: any?)
	local base = self:GetBaseFromPlayer(player)
	if not base then
		return {
			Ok = false,
			Reason = 'NoBase',
		}
	end

	local microwaveId = self:GetEquippedMicrowaveId(player)
	local entry = getMicrowaveShopEntry(microwaveId)
	if not entry then
		return {
			Ok = false,
			Reason = 'UnknownMicrowave',
		}
	end

	local data = self:GetMicrowaveUpgradeData(player, microwaveId)
	local reward = getMicrowaveUpgradeReward(data.UpgradeCount)
	local cash = tonumber(Framework:GetService('DataService'):GetData(player.UserId, 'Cash')) or 0
	local quote = getMicrowaveBulkUpgradeQuote(data, cash, requestedAmount or 1)
	local baseStats = getMicrowaveBaseStats(microwaveId)
	local maxCookSpeed = tonumber((getMicrowaveUpgradeConfig().CookSpeed or {}).Max) or 3
	local currentCookSpeed = math.clamp(baseStats.CookSpeed + data.CookSpeedBonus, 0.1, maxCookSpeed)
	local nextCookSpeed = math.clamp(baseStats.CookSpeed + data.CookSpeedBonus + quote.CookSpeedGain, 0.1, maxCookSpeed)

	return {
		Ok = true,
		MicrowaveId = microwaveId,
		DisplayName = tostring(entry.DisplayName or microwaveId),
		UpgradeCount = data.UpgradeCount,
		MicrowaveLevel = getMicrowaveLevel(data.UpgradeCount),
		NextMicrowaveLevel = getMicrowaveLevel(quote.FinalUpgradeCount),
		UpgradesPerLevel = getMicrowaveUpgradesPerLevel(),
		LevelProgress = (data.UpgradeCount % getMicrowaveUpgradesPerLevel()) / getMicrowaveUpgradesPerLevel(),
		NextLevelProgress = (quote.FinalUpgradeCount % getMicrowaveUpgradesPerLevel()) / getMicrowaveUpgradesPerLevel(),
		BaseLuckBonus = baseStats.LuckBonus,
		BaseMutationLuckBonus = baseStats.MutationLuckBonus,
		BaseCookSpeed = baseStats.CookSpeed,
		LuckBonus = baseStats.LuckBonus + data.LuckBonus,
		MutationLuckBonus = baseStats.MutationLuckBonus + data.MutationLuckBonus,
		CookSpeed = currentCookSpeed,
		NextLuckBonus = baseStats.LuckBonus + data.LuckBonus + quote.LuckGain,
		NextMutationLuckBonus = baseStats.MutationLuckBonus + data.MutationLuckBonus + quote.MutationLuckGain,
		NextCookSpeed = nextCookSpeed,
		LuckGain = reward.LuckGain,
		MutationLuckGain = reward.MutationLuckGain,
		CookSpeedGain = reward.CookSpeedGain,
		BulkLuckGain = quote.LuckGain,
		BulkMutationLuckGain = quote.MutationLuckGain,
		BulkCookSpeedGain = math.max(0, nextCookSpeed - currentCookSpeed),
		IsMilestone = reward.IsMilestone,
		BulkIsMilestone = quote.IsMilestone,
		RequestedAmount = requestedAmount or 1,
		PurchaseAmount = quote.Amount,
		AffordablePurchaseAmount = quote.ActualAffordableAmount,
		NextPrice = quote.TotalCost,
		SinglePrice = getMicrowaveUpgradeCost(data.UpgradeCount),
		CanAfford = cash >= quote.TotalCost and quote.ActualAffordableAmount > 0,
		Cash = cash,
	}
end

function BaseService:RefreshMicrowaveUpgrade(player: Player)
	local state = self:GetMicrowaveUpgradeState(player)
	local base = self:GetBaseFromPlayer(player)
	if base and base.UpdateMicrowaveUpgradeDisplay then
		base:UpdateMicrowaveUpgradeDisplay(state)
	end
	Framework:GetController('BaseController').Server.Fire:MicrowaveUpgradeChanged(player, state)
	return state
end

function BaseService:BuyMicrowaveUpgrade(player: Player, requestedAmount: any?)
	local state = self:GetMicrowaveUpgradeState(player, requestedAmount)
	if not state.Ok or not state.NextPrice then
		return state
	end

	if state.Cash < state.NextPrice or (tonumber(state.AffordablePurchaseAmount) or 0) <= 0 then
		state.Reason = 'NotEnoughCash'
		return state
	end

	local dataService = Framework:GetService('DataService')
	if not dataService:AddPlayerData(player.UserId, 'Cash', -state.NextPrice) then
		state.Ok = false
		state.Reason = 'SpendFailed'
		return state
	end

	local data, microwaveId, allData = self:GetMicrowaveUpgradeData(player, state.MicrowaveId)
	local maxCookSpeed = tonumber((getMicrowaveUpgradeConfig().CookSpeed or {}).Max) or 3
	for _ = 1, math.max(1, math.floor(tonumber(state.PurchaseAmount) or 1)) do
		local reward = getMicrowaveUpgradeReward(data.UpgradeCount)
		data.UpgradeCount += 1
		data.LuckBonus += reward.LuckGain
		data.MutationLuckBonus += reward.MutationLuckGain
		data.CookSpeedBonus = math.min(maxCookSpeed, data.CookSpeedBonus + reward.CookSpeedGain)
	end

	if not self:SaveMicrowaveUpgradeData(player, microwaveId, data, allData) then
		dataService:AddPlayerData(player.UserId, 'Cash', state.NextPrice)
		state.Ok = false
		state.Reason = 'SaveFailed'
		return state
	end

	self:RefreshMicrowaveUpgrade(player)
	return self:GetMicrowaveUpgradeState(player, requestedAmount)
end

function BaseService:GetDefaultUnlockedPadCount(): number
	return tonumber(self:GetPadsConfig().DefaultEnabledCount) or 1
end

function BaseService:GetUnlockedPadCount(player: Player): number
	local dataService = Framework:GetService('DataService')
	local count = dataService:GetData(player.UserId, self:GetPadUnlockDataKey())
	if type(count) ~= 'number' then
		count = self:GetDefaultUnlockedPadCount()
		dataService:UpdatePlayerData(player.UserId, self:GetPadUnlockDataKey(), count)
	end
	return math.max(self:GetDefaultUnlockedPadCount(), math.floor(count))
end

function BaseService:NormalizePlayerStage(player: Player, base)
	local stage = self:GetPlayerStage(player)
	local unlockedCount = self:GetUnlockedPadCount(player)
	while base and unlockedCount > base:GetStagePadCount(stage) do
		local nextStage = base:GetNextStage(stage)
		if not nextStage then
			break
		end

		if not self:SetPlayerStage(player, nextStage) then
			break
		end

		stage = nextStage
		self:SetUnlockedPadCount(player, unlockedCount)
	end

	return stage, unlockedCount
end

function BaseService:GetStageForPadIndex(currentStage: number, padIndex: number, base): number?
	local stage = currentStage
	while base and padIndex > base:GetStagePadCount(stage) do
		local nextStage = base:GetNextStage(stage)
		if not nextStage then
			return nil
		end
		stage = nextStage
	end
	return stage
end

function BaseService:GetPreviousStagePadCount(stage: number): number
	local previousStage = stage - 1
	if previousStage < 1 then
		return 0
	end

	local config = self:GetStageConfig(previousStage)
	return tonumber(config and config.Pads) or 0
end

function BaseService:SetUnlockedPadCount(player: Player, count: number)
	local dataService = Framework:GetService('DataService')
	local value = math.max(self:GetDefaultUnlockedPadCount(), math.floor(count))
	return dataService:UpdatePlayerData(player.UserId, self:GetPadUnlockDataKey(), value)
end

function BaseService:GetPadPrice(stage: number, padIndex: number): number?
	local stageUnlocks = self:GetPadsConfig().StageUnlocks and self:GetPadsConfig().StageUnlocks[stage]
	local unlockConfig = stageUnlocks and stageUnlocks[padIndex]
	if not unlockConfig then
		local localPadIndex = padIndex - self:GetPreviousStagePadCount(stage) + 1
		unlockConfig = stageUnlocks and stageUnlocks[localPadIndex]
	end
	if not unlockConfig then
		unlockConfig = self:GetPadsConfig().Unlocks and self:GetPadsConfig().Unlocks[padIndex]
	end
	local cost = unlockConfig and unlockConfig.Cost
	return if type(cost) == 'number' then cost else nil
end

function BaseService:GetPadUpgradeState(player: Player)
	local base = self:GetBaseFromPlayer(player)
	if not base then
		return {
			Ok = false,
			Reason = 'NoBase',
		}
	end

	local stage = self:GetPlayerStage(player)
	local unlockedCount = math.min(self:GetUnlockedPadCount(player), base:GetTotalPads())
	local nextPadIndex = unlockedCount + 1
	local targetStage = self:GetStageForPadIndex(stage, nextPadIndex, base)
	local totalPads = base:GetStagePadCount(stage)
	local maxed = targetStage == nil
	local nextPrice = if maxed or targetStage == nil then nil else self:GetPadPrice(targetStage, nextPadIndex)
	local cash = Framework:GetService('DataService'):GetData(player.UserId, 'Cash') or 0

	return {
		Ok = true,
		Stage = stage,
		TargetStage = targetStage,
		UnlockedCount = unlockedCount,
		NextPadIndex = if maxed then nil else nextPadIndex,
		NextPrice = nextPrice,
		TotalPads = totalPads,
		Maxed = maxed,
		CanAfford = nextPrice ~= nil and cash >= nextPrice,
		Cash = cash,
	}
end

function BaseService:RefreshPadUpgrade(player: Player)
	local state = self:GetPadUpgradeState(player)
	local base = self:GetBaseFromPlayer(player)
	if base then
		base:UpdatePadUpgradeDisplay(state)
	end
	Framework:GetController('BaseController').Server.Fire:PadUpgradeChanged(player, state)
	return state
end

function BaseService:BuyNextPad(player: Player)
	local state = self:GetPadUpgradeState(player)
	if not state.Ok or state.Maxed or not state.NextPadIndex or not state.NextPrice then
		return state
	end

	if state.Cash < state.NextPrice then
		state.Reason = 'NotEnoughCash'
		return state
	end

	local dataService = Framework:GetService('DataService')
	if not dataService:AddPlayerData(player.UserId, 'Cash', -state.NextPrice) then
		state.Ok = false
		state.Reason = 'SpendFailed'
		return state
	end

	if not self:SetUnlockedPadCount(player, state.NextPadIndex) then
		dataService:AddPlayerData(player.UserId, 'Cash', state.NextPrice)
		state.Ok = false
		state.Reason = 'SaveFailed'
		return state
	end

	local base = self:GetBaseFromPlayer(player)
	local targetStage = state.TargetStage
	local changedStage = base and targetStage and targetStage ~= state.Stage
	if base and changedStage then
		if not self:SetPlayerStage(player, targetStage) then
			dataService:AddPlayerData(player.UserId, 'Cash', state.NextPrice)
			self:SetUnlockedPadCount(player, state.UnlockedCount)
			state.Ok = false
			state.Reason = 'StageSaveFailed'
			return state
		end

		local carriedUnlockedCount = state.NextPadIndex
		self:SetUnlockedPadCount(player, carriedUnlockedCount)
		if not base:SetStage(targetStage, carriedUnlockedCount) then
			dataService:AddPlayerData(player.UserId, 'Cash', state.NextPrice)
			self:SetPlayerStage(player, state.Stage)
			self:SetUnlockedPadCount(player, state.UnlockedCount)
			state.Ok = false
			state.Reason = 'StageLoadFailed'
			return state
		end
		player.RespawnLocation = base.SpawnLocation
		local baseFolder = base.BaseFolder
		task.defer(function()
			if player.Parent == Players and base.Owner == player then
				Framework:GetController('BaseController').Server.Fire:ClaimBase(player, baseFolder)
				self:RefreshPadUpgrade(player)
			end
		end)
	elseif base then
		base:ApplyPadUnlockCount(state.NextPadIndex)
	end

	return self:RefreshPadUpgrade(player)
end

function BaseService:SetupBases()
	local baseFolders = workspace:WaitForChild('Bases'):GetChildren()
	table.sort(baseFolders, function(a, b)
		return (tonumber(a.Name:match('%d+')) or math.huge) < (tonumber(b.Name:match('%d+')) or math.huge)
	end)

	for _, baseFolder in ipairs(baseFolders) do
		table.insert(self.Bases, Framework.Components.BaseServer:new(baseFolder))
	end
end

function BaseService:GetBaseFromPlayer(player:Player)
	for i, base in ipairs(self.Bases) do
		if base.Owner == player then
			return base
		end
	end
	return nil
end

function BaseService:GetVacantBase()
	for i, base in ipairs(self.Bases) do
		if base.Owner == nil then
			return base
		end
	end
	return nil
end

function BaseService.Client:GetPadUpgradeState(player: Player)
	return self:GetPadUpgradeState(player)
end

function BaseService.Client:BuyNextPad(player: Player)
	return self:BuyNextPad(player)
end

function BaseService.Client:GetFridgeUpgradeState(player: Player, requestedAmount: any?)
	return self:GetFridgeUpgradeState(player, requestedAmount)
end

function BaseService.Client:BuyFridgeUpgrade(player: Player, requestedAmount: any?)
	return self:BuyFridgeUpgrade(player, requestedAmount)
end

function BaseService.Client:GetMicrowaveUpgradeState(player: Player, requestedAmount: any?)
	return self:GetMicrowaveUpgradeState(player, requestedAmount)
end

function BaseService.Client:BuyMicrowaveUpgrade(player: Player, requestedAmount: any?)
	return self:BuyMicrowaveUpgrade(player, requestedAmount)
end



return BaseService
