local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local StartHitService = Framework:CreateService("StartHitService")

function StartHitService:Initialize()
	self.KickCalculator = Framework.Utilities.KickCalculator
	self.Blink = require(game:GetService("ReplicatedStorage"):WaitForChild("Blink"):WaitForChild("Server"))
	self.DataService = Framework:GetService("DataService")
	
	self.MapCoreFolder = workspace:WaitForChild("MapCore")
	self.LandingArea = self.MapCoreFolder:WaitForChild("LandingArea")
end

function StartHitService:Start()
	self.Blink.StartHit.On(function(Player: Player, BarValue: number) 
		BarValue = math.clamp(BarValue or 0, 0, 1)

		local profile = self.DataService:GetProfile(Player)
		if not profile then return end

		-- HitPower scales with the Speed upgrade: base 1 + 0.1 per upgrade level
		local hitPower = 1 + (profile.Data.Upgrades.Speed * 0.1)

		local Character = Player.Character
		if not Character then return end

		local RootPart = Character:FindFirstChild("HumanoidRootPart")
		if not RootPart then return end

		local Result = self.KickCalculator.Compute(hitPower, BarValue, RootPart, self.LandingArea)

		self.Blink.HitInfo.FireAll({
			Player = Player,
			Result = Result,
		})
	end)
end

return StartHitService
