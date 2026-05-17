local FridgeConfig = {
	UpgradesPerLevel = 10,
	MaxBulkUpgrades = 10000,

	Cost = {
		BaseCost = 100,
		GrowthRate = 1.13,
		MilestoneMultiplier = 3,
		RoundToNearest = 5,
	},

	PumpPower = {
		BaseSmallGain = 1,
		SmallGainLevelPower = 0.75,
		MilestoneGainMultiplier = 10,
	},

	Mutation = {
		MilestonePointGain = 1,
		BonusPointEveryLevels = 5,
		BonusPointAmount = 1,
		MaxChance = 0.65,
		ScalingRate = 0.045,
	},

	LuckyBlockXP = {
		BaseXP = 25,
		GrowthRate = 1.35,
		MaxLevelsPerPump = 5,
	},

	Mutations = {
		{ Name = "Gold", Weight = 500, RewardMultiplier = 1.25 },
		{ Name = "Lava", Weight = 250, RewardMultiplier = 1.5 },
		{ Name = "Diamond", Weight = 125, RewardMultiplier = 2 },
		{ Name = "Rainbow", Weight = 50, RewardMultiplier = 3 },
		{ Name = "Galaxy", Weight = 20, RewardMultiplier = 5 },
		{ Name = "Glitch", Weight = 10, RewardMultiplier = 8 },
		{ Name = "DarkMatter", Weight = 3, RewardMultiplier = 15 },
	},
}

return FridgeConfig
