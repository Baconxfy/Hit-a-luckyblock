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
		
		Studio = {
			Enabled = game:GetService('RunService'):IsStudio(),
			StartingCash = 0,
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
