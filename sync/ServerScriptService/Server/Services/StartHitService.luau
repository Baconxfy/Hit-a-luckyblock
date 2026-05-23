local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local StartHitService = Framework:CreateService("StartHitService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

function StartHitService:Initialize()
	self.KickCalculator = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("KickCalculator"))
	self.MapCoreFolder = workspace:WaitForChild("MapCore")
	self.LandingArea = self.MapCoreFolder:WaitForChild("LandingArea")
end

function StartHitService:Start()
	self.DataService = Framework:GetService("DataService")
	self.HitLuckyBlockController = Framework:GetController("HitLuckyBlockController")
end

function StartHitService.Client:StartHit(player: Player, barValue: number)
	barValue = math.clamp(tonumber(barValue) or 0, 0, 1)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local hitPower = self.DataService:GetData(player.UserId, "HitPower") or 0
	local result = self.KickCalculator.Compute(hitPower, barValue, rootPart, self.LandingArea)

	self.HitLuckyBlockController.Server.FireAll:HitInfo({
		Player = player,
		Result = result,
	})
end

return StartHitService
