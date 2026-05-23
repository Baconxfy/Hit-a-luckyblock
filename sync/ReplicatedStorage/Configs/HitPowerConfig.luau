--[[
	HitPowerConfig
	--------------
	Converts a player's HitPower + bar accuracy into a launch distance.

	The client sends ONLY the bar accuracy (0..1) up to the server.
	The server uses this module to compute the actual distance, so HitPower
	cannot be spoofed by the client.
--]]

local HitPowerConfig = {}

-- Minimum & maximum distance the lucky block can ever travel.
HitPowerConfig.MinDistance = 25
HitPowerConfig.MaxDistance = 100000

-- The 5 grade tiers (must match HitMinigameClient labels).
HitPowerConfig.Grades = {
	{ MinAccuracy = 0,    Name = "BAD",     BaseDistance = 25,  PowerScale = 0.4 },
	{ MinAccuracy = 0.25, Name = "OKAY",    BaseDistance = 35,  PowerScale = 0.6 },
	{ MinAccuracy = 0.50, Name = "GOOD",    BaseDistance = 50,  PowerScale = 0.85 },
	{ MinAccuracy = 0.75, Name = "GREAT",   BaseDistance = 70,  PowerScale = 1.0 },
	{ MinAccuracy = 0.90, Name = "PERFECT", BaseDistance = 100, PowerScale = 1.3 },
}

-- Distance = BaseDistance(grade) + sqrt(HitPower) * PowerToDistance * PowerScale(grade)
HitPowerConfig.PowerToDistance = 8

function HitPowerConfig.GetGradeForAccuracy(accuracy: number)
	accuracy = math.clamp(accuracy or 0, 0, 1)
	local best = HitPowerConfig.Grades[1]
	for _, grade in ipairs(HitPowerConfig.Grades) do
		if accuracy >= grade.MinAccuracy then
			best = grade
		end
	end
	return best
end

function HitPowerConfig.ComputeDistance(accuracy: number, hitPower: number)
	hitPower = math.max(hitPower or 0, 0)
	local grade = HitPowerConfig.GetGradeForAccuracy(accuracy)
	local raw = grade.BaseDistance + math.sqrt(hitPower) * HitPowerConfig.PowerToDistance * grade.PowerScale
	local clamped = math.clamp(raw, HitPowerConfig.MinDistance, HitPowerConfig.MaxDistance)
	return clamped, grade
end

return HitPowerConfig
