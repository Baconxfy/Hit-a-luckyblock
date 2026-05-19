local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local StartHitService = Framework:CreateService("StartHitService")

StartHitService.Client = {}

function StartHitService:Initialize()
	self.HitLuckyBlockService = nil
end

function StartHitService:Start()
	self.HitLuckyBlockService = Framework:GetService("HitLuckyBlockService")
end

function StartHitService:StartHit(player: Player, barValue: number)
	if not self.HitLuckyBlockService then
		return {
			Ok = false,
			Reason = "HitLuckyBlockServiceNotReady",
		}
	end

	return self.HitLuckyBlockService:StartHitSequence(player, barValue)
end

function StartHitService:BlockLanded(player: Player, flightId: string, landingPosition: Vector3, flatDirection: Vector3)
	if not self.HitLuckyBlockService then
		return
	end

	self.HitLuckyBlockService:BlockLanded(player, flightId, landingPosition, flatDirection)
end

function StartHitService:RevealFinished(player: Player, flightId: string)
	if not self.HitLuckyBlockService then
		return
	end

	self.HitLuckyBlockService:RevealFinished(player, flightId)
end

function StartHitService.Client.StartHit(service, player: Player, barValue: number)
	return service:StartHit(player, barValue)
end

function StartHitService.Client.BlockLanded(
	service,
	player: Player,
	flightId: string,
	landingPosition: Vector3,
	flatDirection: Vector3
)
	service:BlockLanded(player, flightId, landingPosition, flatDirection)
end

function StartHitService.Client.RevealFinished(service, player: Player, flightId: string)
	service:RevealFinished(player, flightId)
end

return StartHitService