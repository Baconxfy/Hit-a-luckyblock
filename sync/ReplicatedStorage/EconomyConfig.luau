local EconomyConfig = {}

EconomyConfig.StartingCash = 0
EconomyConfig.StartingKickPower = 1
EconomyConfig.StartingBaseFloor = 1
EconomyConfig.MaxBaseFloor = 3
EconomyConfig.SlotsPerFloor = 10
EconomyConfig.PassiveIncomeInterval = 1

EconomyConfig.FloorUpgradeCosts = {
	[2] = 5000,
	[3] = 25000,
}

EconomyConfig.SpeedUpgradeBaseCost = 250
EconomyConfig.SpeedUpgradeGrowth = 1.55
EconomyConfig.SpeedPerLevel = 1.5
EconomyConfig.BaseWalkSpeed = 16
EconomyConfig.MaxSpeedLevel = 30

EconomyConfig.WeightTrainingInterval = 1
EconomyConfig.Weights = {
	Starter = { Cost = 0, PowerPerTick = 1, RequiredKickPower = 0 },
	Dumbbell = { Cost = 250, PowerPerTick = 5, RequiredKickPower = 25 },
	Barbell = { Cost = 1500, PowerPerTick = 18, RequiredKickPower = 150 },
	Heavy = { Cost = 8000, PowerPerTick = 60, RequiredKickPower = 750 },
}

EconomyConfig.RebirthRequirements = {
	[1] = 1000,
	[2] = 5000,
	[3] = 25000,
	[4] = 100000,
	[5] = 500000,
}

EconomyConfig.DefaultRebirthRequirement = 1000000

EconomyConfig.DefaultBrainrotEarnRate = 5
EconomyConfig.BrainrotEarnRates = {
	B1 = 5,
	B10 = 8,
	B11 = 10,
	B12 = 12,
	B13 = 15,
	B14 = 18,
	B15 = 22,
	B16 = 28,
	B17 = 35,
	B18 = 45,
	B19 = 60,
}

EconomyConfig.MutationMultipliers = {
	Default = 1,
	Candy = 1.2,
	Lava = 1.35,
	Hacker = 1.6,
	Gold = 2,
	Galaxy = 3,
	Rainbow = 4,
	Diamond = 6,
}

EconomyConfig.UpgradeBaseCost = 250
EconomyConfig.UpgradeCostGrowth = 1.65
EconomyConfig.UpgradeIncomeBonusPerLevel = 0.25
EconomyConfig.SellValueSeconds = 45
EconomyConfig.CashMultiplierPerRebirth = 0.5

function EconomyConfig.GetCashMultiplier(rebirths)
	return 1 + math.max(rebirths or 0, 0) * EconomyConfig.CashMultiplierPerRebirth
end

function EconomyConfig.GetSpeedUpgradeCost(currentLevel)
	local level = math.max(currentLevel or 0, 0)
	return math.floor(EconomyConfig.SpeedUpgradeBaseCost * (EconomyConfig.SpeedUpgradeGrowth ^ level))
end

function EconomyConfig.GetWalkSpeed(speedLevel)
	return EconomyConfig.BaseWalkSpeed + math.max(speedLevel or 0, 0) * EconomyConfig.SpeedPerLevel
end

function EconomyConfig.GetRebirthRequirement(currentRebirths)
	local nextRebirth = math.max(currentRebirths or 0, 0) + 1
	return EconomyConfig.RebirthRequirements[nextRebirth]
		or math.floor(EconomyConfig.DefaultRebirthRequirement * (nextRebirth - #EconomyConfig.RebirthRequirements))
end

function EconomyConfig.GetBrainrotBaseEarnRate(entry)
	if not entry then
		return EconomyConfig.DefaultBrainrotEarnRate
	end
	return EconomyConfig.BrainrotEarnRates[entry.Brainrot]
		or EconomyConfig.BrainrotEarnRates[entry.SourceName]
		or entry.EarnRate
		or EconomyConfig.DefaultBrainrotEarnRate
end

function EconomyConfig.GetMutationMultiplier(mutation)
	return EconomyConfig.MutationMultipliers[mutation or "Default"] or 1
end

function EconomyConfig.GetBrainrotEarnRate(entry)
	local level = math.max(entry and entry.Level or 1, 1)
	local levelMultiplier = 1 + (level - 1) * EconomyConfig.UpgradeIncomeBonusPerLevel
	return EconomyConfig.GetBrainrotBaseEarnRate(entry) * EconomyConfig.GetMutationMultiplier(entry and entry.Mutation) * levelMultiplier
end

function EconomyConfig.GetBrainrotUpgradeCost(entry)
	local level = math.max(entry and entry.Level or 1, 1)
	local baseEarn = EconomyConfig.GetBrainrotBaseEarnRate(entry)
	return math.floor((EconomyConfig.UpgradeBaseCost + baseEarn * 25) * (EconomyConfig.UpgradeCostGrowth ^ (level - 1)))
end

function EconomyConfig.GetBrainrotSellValue(entry)
	return math.floor(EconomyConfig.GetBrainrotEarnRate(entry) * EconomyConfig.SellValueSeconds)
end

return EconomyConfig