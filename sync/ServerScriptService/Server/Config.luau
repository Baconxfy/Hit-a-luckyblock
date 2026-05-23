local Config = {
	RateLimits = {
		-- Fallback if no more-specific rule matches
		-- burst = bucket capacity, refill = tokens added per 'every' seconds (default every=1s)
		Default = { burst = 20, refill = 10, every = 1 },

		-- Service rules (client -> server).
		Service = {
			["*"] = { burst = 100, refill = 100 }, -- global catch-all
		},
	},

	Shared = {
		DataVersion = "HitALuckyblock-v1",
		DataVersionStudio = "HitALuckyblock-v1-studio",
		
		LeaderstatsCategories = {
			"Cash",
			"Rebirths",
		},

		Economy = {
			Speed = {
				BaseCost = 250,
				CostGrowth = 1.55,
				BaseWalkSpeed = 16,
				SpeedPerUpgrade = 1.5,
				MaxUpgradeLevel = 30,
			},
			Rebirths = {
				BaseRequirement = 10000,
				RequirementGrowth = 5,
				RebirthRequirements = { 10000, 50000, 150000, 500000, 1000000 },
				DefaultRebirthRequirement = 1000000,
			},
			CashMultiplierPerRebirth = 0.5,
		},
		
		Studio = {
			Enabled = game:GetService('RunService'):IsStudio(),
			StartingCash = 0,
		},
		
		ProfileTemplate = {
			Likes = 0,
			Cash = 0,
			Rebirths = 0,
			
			HitPower = 0,
			RunSpeed = 0,	
			
			Inventory = {
				Brainrots = {},
				Weights = {},
			},
			
			BrainrotIndex = {},
			
			Plot = {
				Floor1 = {
					["Slot1"] = "None", 
					["Slot2"] = "None",
					["Slot3"] = "None",
					["Slot4"] = "None",
					["Slot5"] = "None",
					["Slot6"] = "None",
					["Slot7"] = "None",
					["Slot8"] = "None",
					["Slot9"] = "None",
					["Slot10"] = "None",
				},
			}
		},
		
		ControllerCallTimeout = 4.0,

		Button = {
			Enabled = true,
			HoverEnabled = true,
			PressEnabled = true,
			HoverScale = 1.06,
			PressScale = 0.94,
			HoverTime = 0.12,
			PressDownTime = 0.07,
			PressUpTime = 0.10,
			ClickSlopPx = 6,
			HoverEasingStyle = Enum.EasingStyle.Quint,
			HoverEasingDirection = Enum.EasingDirection.Out,
			PressDownEasingStyle = Enum.EasingStyle.Quint,
			PressDownEasingDirection = Enum.EasingDirection.Out,
			PressUpEasingStyle = Enum.EasingStyle.Back,
			PressUpEasingDirection = Enum.EasingDirection.Out,
		},

		Menu = {
			OpenTime = 0.28,
			CloseTime = 0.18,
			BlurSize = 14,
			ScaleClosed = 0.94,
		},
	},
}

return Config
