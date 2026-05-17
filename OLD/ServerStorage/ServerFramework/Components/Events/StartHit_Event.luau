--< Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--< Modules
local KickCalculator = require(ReplicatedStorage:WaitForChild("Framework"):WaitForChild("KickCalculator"))
local EzProfile = require(game:GetService("ServerStorage"):WaitForChild("ServerPackages"):WaitForChild("EzProfile"))
local Blink = require(ReplicatedStorage:WaitForChild("Blink"):WaitForChild("Server"))

--< Workspace Variables
local MapCoreFolder = workspace:WaitForChild("MapCore")
local LandingArea = MapCoreFolder:WaitForChild("LandingArea")

return function()
	
	Blink.StartHit.On(function(Player: Player, BarValue: number) 
		
		BarValue = BarValue or 0
		if BarValue > 1  then
			BarValue = 0
		end
		
		local DataFolder = EzProfile:GetProfileFolder(Player)
		if not DataFolder then return end
		
		
		local HitPower :NumberValue = DataFolder:FindFirstChild("HitPower")
		if not HitPower then return end
		
		local Character = Player.Character
		if not Character then return end
		
		local RootPart :BasePart = Character:FindFirstChild("HumanoidRootPart")
		if not RootPart then return end
		
	
		
		local Result = KickCalculator.Compute(HitPower.Value or 0, BarValue, RootPart, LandingArea)
		print("BarValue:", BarValue)
		print("HitPower:", HitPower.Value)
		print(Result)
	
		Blink.HitInfo.FireAll({
			Player = Player,
			Result = Result			
		})
		
		
		
		
		
			
	end)
	
end