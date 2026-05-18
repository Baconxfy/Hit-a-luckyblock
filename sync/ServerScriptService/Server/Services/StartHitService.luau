local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Framework)

local StartHitService = Framework:CreateService("StartHitService")

StartHitService.Client = {}

function StartHitService:Initialize()
	self.HitLuckyBlockService = nil
end

function StartHitService:Start()
	self.HitLuckyBlockService = Framework:GetService("HitLuckyBlockService")
end

function StartHitService:StartHit(player, clientOrigin, clientDirection)
	if not self.HitLuckyBlockService then
		return {
			Ok = false,
			Reason = "HitServiceNotReady",
		}
	end

	return self.HitLuckyBlockService:HandleHit(player, clientOrigin, clientDirection)
end

function StartHitService.Client:StartHit(player, clientOrigin, clientDirection)
	return StartHitService:StartHit(player, clientOrigin, clientDirection)
end

return StartHitService