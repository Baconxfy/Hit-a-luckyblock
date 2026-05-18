local EconomyMath = {}

local function getEconomy(configOrEconomy)
	if configOrEconomy.Economy then
		return configOrEconomy.Economy
	end

	return configOrEconomy
end

local function roundInteger(value)
	return math.max(0, math.floor(value + 0.5))
end

function EconomyMath.GetCashMultiplier(configOrEconomy, rebirths)
	local economy = getEconomy(configOrEconomy)
	local perRebirth = economy.CashMultiplierPerRebirth or 0

	return 1 + math.max(rebirths or 0, 0) * perRebirth
end

function EconomyMath.GetSpeedUpgradeCost(configOrEconomy, level)
	local economy = getEconomy(configOrEconomy)
	local speed = economy.Speed

	level = math.max(level or 0, 0)

	return roundInteger(speed.BaseCost * speed.CostGrowth ^ level)
end

function EconomyMath.GetWalkSpeed(configOrEconomy, speedLevel)
	local economy = getEconomy(configOrEconomy)
	local speed = economy.Speed

	speedLevel = math.clamp(speedLevel or 0, 0, speed.MaxUpgradeLevel)

	return speed.BaseWalkSpeed + speed.SpeedPerUpgrade * speedLevel
end

function EconomyMath.GetRebirthRequirement(configOrEconomy, rebirths)
	local economy = getEconomy(configOrEconomy)
	local rebirthConfig = economy.Rebirths

	rebirths = math.max(rebirths or 0, 0)

	return roundInteger(rebirthConfig.BaseRequirement * rebirthConfig.RequirementGrowth ^ rebirths)
end

function EconomyMath.GetBrainrotBaseEarnRate(configOrEconomy, brainrotName)
	local economy = getEconomy(configOrEconomy)
	local brainrots = economy.Brainrots

	return brainrots.BaseEarnRates[brainrotName] or brainrots.DefaultBaseEarnRate
end

function EconomyMath.GetMutationMultiplier(configOrEconomy, mutationName)
	local economy = getEconomy(configOrEconomy)
	local brainrots = economy.Brainrots

	return brainrots.MutationMultipliers[mutationName] or brainrots.MutationMultipliers.Default or 1
end

function EconomyMath.GetBrainrotEarnRate(configOrEconomy, brainrotName, mutationName, level)
	local economy = getEconomy(configOrEconomy)
	local brainrots = economy.Brainrots

	level = math.max(level or 1, 1)

	local baseRate = EconomyMath.GetBrainrotBaseEarnRate(economy, brainrotName)
	local mutationMultiplier = EconomyMath.GetMutationMultiplier(economy, mutationName)
	local levelMultiplier = brainrots.Upgrade.EarnRateGrowth ^ (level - 1)

	return roundInteger(baseRate * mutationMultiplier * levelMultiplier)
end

function EconomyMath.GetBrainrotUpgradeCost(configOrEconomy, brainrotName, mutationName, level)
	local economy = getEconomy(configOrEconomy)
	local brainrots = economy.Brainrots

	level = math.max(level or 1, 1)

	local baseRate = EconomyMath.GetBrainrotBaseEarnRate(economy, brainrotName)
	local mutationMultiplier = EconomyMath.GetMutationMultiplier(economy, mutationName)

	return roundInteger(brainrots.Upgrade.BaseCost * baseRate * mutationMultiplier * brainrots.Upgrade.CostGrowth ^ (level - 1))
end

function EconomyMath.GetBrainrotSellValue(configOrEconomy, brainrotName, mutationName, level)
	local economy = getEconomy(configOrEconomy)
	local brainrots = economy.Brainrots

	level = math.max(level or 1, 1)

	local earnRate = EconomyMath.GetBrainrotEarnRate(economy, brainrotName, mutationName, level)

	return roundInteger(earnRate * brainrots.SellValue.BaseMultiplier * brainrots.SellValue.LevelMultiplier ^ (level - 1))
end

function EconomyMath.GetPassiveIncome(configOrEconomy, slots)
	local total = 0

	for _, slotData in pairs(slots or {}) do
		if typeof(slotData) == "table" and slotData.Brainrot then
			total += EconomyMath.GetBrainrotEarnRate(
				configOrEconomy,
				slotData.Brainrot,
				slotData.Mutation or "Default",
				slotData.Level or 1
			)
		end
	end

	return total
end

return EconomyMath