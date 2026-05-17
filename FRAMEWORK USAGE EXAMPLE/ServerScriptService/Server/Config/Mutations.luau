local MutationConfig = {
	DefaultMutationLuck = 1,

	Mutations = {
		Normal = {
			DisplayName = "Normal",
			Multiplier = 1,
			IncomeMultiplier = 1,
			UpgradeCostMultiplier = 1,
			BaseWeight = 40000,
			LuckPower = -0.45,
			IsMutation = false,
		},

		Gold = {
			DisplayName = "Gold",
			Multiplier = 1.5,
			IncomeMultiplier = 1.5,
			UpgradeCostMultiplier = 1.15,
			BaseWeight = 940000,
			LuckPower = 0.25,
			IsMutation = true,
		},

		Diamond = {
			DisplayName = "Diamond",
			Multiplier = 3,
			IncomeMultiplier = 3,
			UpgradeCostMultiplier = 1.3,
			BaseWeight = 12500,
			LuckPower = 0.65,
			IsMutation = true,
		},

		Lava = {
			DisplayName = "Lava",
			Multiplier = 6,
			IncomeMultiplier = 6,
			UpgradeCostMultiplier = 1.55,
			BaseWeight = 5000,
			LuckPower = 1.00,
			IsMutation = true,
		},

		Glitch = {
			DisplayName = "Glitch",
			Multiplier = 10,
			IncomeMultiplier = 10,
			UpgradeCostMultiplier = 1.75,
			BaseWeight = 1800,
			LuckPower = 1.35,
			IsMutation = true,
		},

		Galaxy = {
			DisplayName = "Galaxy",
			Multiplier = 18,
			IncomeMultiplier = 18,
			UpgradeCostMultiplier = 1.9,
			BaseWeight = 550,
			LuckPower = 1.75,
			IsMutation = true,
		},

		DarkMatter = {
			DisplayName = "Dark Matter",
			Multiplier = 35,
			IncomeMultiplier = 35,
			UpgradeCostMultiplier = 2.2,
			BaseWeight = 140,
			LuckPower = 2.20,
			IsMutation = true,
		},

		Rainbow = {
			DisplayName = "Rainbow",
			Multiplier = 75,
			IncomeMultiplier = 75,
			UpgradeCostMultiplier = 2.5,
			BaseWeight = 10,
			LuckPower = 2.75,
			IsMutation = true,
		},
	},
}

return MutationConfig
