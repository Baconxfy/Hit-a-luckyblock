local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()

local Economy = {
	StartingCash = 0,
	StartingKickPower = 1,
	StartingBaseFloor = 1,
	MaxBaseFloor = 3,
	SlotsPerFloor = 10,

	PassiveIncomeInterval = 1,

	FloorUpgradeCosts = {
		[2] = 5_000,
		[3] = 25_000,
	},

	CashMultiplierPerRebirth = 0.5,

	Speed = {
		BaseWalkSpeed = 16,
		SpeedPerUpgrade = 1,
		MaxUpgradeLevel = 25,
		BaseCost = 100,
		CostGrowth = 1.35,
	},

	KickPower = {
		BaseReward = 10,
		RewardPerPower = 3,
		PowerGainPerHit = 1,
		BaseDistance = 35,
		DistancePerPower = 3.5,
		MaxDistance = 250,
		BaseArcHeight = 16,
		ArcHeightPerPower = 0.35,
		MaxArcHeight = 80,
	},

	Rebirths = {
		BaseRequirement = 100_000,
		RequirementGrowth = 2.5,
	},

	Brainrots = {
		DefaultBaseEarnRate = 1,

		BaseEarnRates = {
			B1 = 1,
			B10 = 10,
			B11 = 15,
			B12 = 25,
			B13 = 40,
			B14 = 60,
			B15 = 90,
			B16 = 125,
			B17 = 175,
			B18 = 250,
			B19 = 350,
		},

		MutationMultipliers = {
			Default = 1,
			Gold = 2,
			Diamond = 4,
			Rainbow = 8,
			Galaxy = 16,
		},

		Upgrade = {
			BaseCost = 50,
			CostGrowth = 1.4,
			EarnRateGrowth = 1.2,
			MaxLevel = 50,
		},

		SellValue = {
			BaseMultiplier = 10,
			LevelMultiplier = 1.15,
		},
	},
}

local Config = {}

Config.RateLimits = {
	Default = {
		Calls = 10,
		Window = 1,
	},

	Service = {
		["*"] = {
			Calls = 20,
			Window = 1,
		},

		HitLuckyBlockService = {
			Calls = 8,
			Window = 1,
		},

		StartHitService = {
			Calls = 8,
			Window = 1,
		},

		DataService = {
			Calls = 12,
			Window = 1,
		},
	},
}

Config.Shared = {
	DataVersion = "HitALuckyblock_v2",
	DataVersionStudio = "HitALuckyblock_Studio_v2",

	LeaderstatsCategories = {
		"Cash",
		"Rebirths",
		"KickPower",
	},

	Studio = {
		Enabled = isStudio,
		StartingCash = 0,
	},

	ControllerCallTimeout = 4,

	Button = {
		Keyboard = {
			Hit = Enum.KeyCode.E,
			OpenShop = Enum.KeyCode.F,
		},

		Gamepad = {
			Hit = Enum.KeyCode.ButtonR2,
			OpenShop = Enum.KeyCode.ButtonY,
		},
	},

	Menu = {
		TweenTime = 0.18,
		OpenScale = 1,
		ClosedScale = 0.92,
	},

	LuckyBlock = {
		HitCooldown = 0.35,
		MaxAimDistanceFromCharacter = 20,
		DefaultAimDistance = 90,
		VisualLifetime = 5,

		Flight = {
			Duration = 0.85,
			SpinSpeed = 540,
			LandBounceHeight = 5,
			LandBounceTime = 0.18,
		},
	},

	Economy = Economy,
}

Config.Runtime = {
	ProfileStoreName = if isStudio then Config.Shared.DataVersionStudio else Config.Shared.DataVersion,

	ProfileTemplate = {
		Cash = Economy.StartingCash,
		Rebirths = 0,
		KickPower = Economy.StartingKickPower,
		LastFreeShopClaim = 0,

		Upgrades = {
			Speed = 0,
			Jump = 0,
		},

		Inventory = {
			EquippedWeight = "Starter",
			OwnedWeights = {
				Starter = true,
			},
		},

		Plot = {
			BaseFloor = Economy.StartingBaseFloor,
			Floor2 = {},
			Floor3 = {},
			Slots = {},
		},
	},
}

return Config