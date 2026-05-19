local KickCalculator = {}

local CONFIG = {
	MIN_POWER = 0,
	MAX_POWER = 100000,
	POWER_EXPONENT = 0.6,

	BAR_MIN_MULT = 0.1,
	BAR_MAX_MULT = 1.2,

	MAX_LUCK = 100,
	LUCK_EXPONENT = 1.2,

	Z_JITTER_MAX_STUDS = 10,
	X_JITTER_MAX_STUDS = 4,
	BORDER_MARGIN = 5,

	FRONT_IS_POSITIVE_Z = true,
	LANDING_Y_OFFSET = 2,
}

local function clamp(n, lo, hi)
	if n < lo then
		return lo
	end

	if n > hi then
		return hi
	end

	return n
end

local function getEconomy(configOrEconomy)
	if configOrEconomy and configOrEconomy.Economy then
		return configOrEconomy.Economy
	end

	return configOrEconomy or {}
end

local function getKickConfig(configOrEconomy)
	local economy = getEconomy(configOrEconomy)
	return economy.KickPower or {}
end

local function normalizePower(hitPower)
	local power = clamp(hitPower or 0, CONFIG.MIN_POWER, CONFIG.MAX_POWER)
	local ratio = power / CONFIG.MAX_POWER

	return ratio ^ CONFIG.POWER_EXPONENT
end

local function barMultiplier(barValue)
	local bar = clamp(barValue or 0, 0, 1)

	return CONFIG.BAR_MIN_MULT + (CONFIG.BAR_MAX_MULT - CONFIG.BAR_MIN_MULT) * bar
end

function KickCalculator.Compute(hitPower, barValue, rootPart, areaPart, rng)
	rng = rng or Random.new()

	local size = areaPart.Size
	local halfX = size.X / 2
	local halfZ = size.Z / 2

	local playerLocal = areaPart.CFrame:PointToObjectSpace(rootPart.Position)
	local lane = clamp(playerLocal.X, -halfX + CONFIG.BORDER_MARGIN, halfX - CONFIG.BORDER_MARGIN)

	local powerNorm = normalizePower(hitPower)
	local mult = barMultiplier(barValue)
	local normalized = clamp(powerNorm * mult, 0, 1)

	local edge = halfZ - CONFIG.BORDER_MARGIN
	local backZ
	local frontZ

	if CONFIG.FRONT_IS_POSITIVE_Z then
		backZ = -edge
		frontZ = edge
	else
		backZ = edge
		frontZ = -edge
	end

	local runway = frontZ - backZ
	local travel = normalized * runway

	local jitterSign = if runway >= 0 then 1 else -1
	local zJitter = (rng:NextNumber() * 2 - 1) * CONFIG.Z_JITTER_MAX_STUDS * normalized * jitterSign

	local loZ = math.min(backZ, frontZ)
	local hiZ = math.max(backZ, frontZ)

	local landingZ = clamp(backZ + travel + zJitter, loZ, hiZ)

	local xJitter = (rng:NextNumber() * 2 - 1) * CONFIG.X_JITTER_MAX_STUDS * normalized
	local landingX = clamp(lane + xJitter, -halfX + CONFIG.BORDER_MARGIN, halfX - CONFIG.BORDER_MARGIN)

	local localLanding = Vector3.new(landingX, CONFIG.LANDING_Y_OFFSET, landingZ)
	local targetPos = areaPart.CFrame:PointToWorldSpace(localLanding)

	local localStart = Vector3.new(lane, playerLocal.Y, backZ)
	local startPos = areaPart.CFrame:PointToWorldSpace(localStart)

	local flatTarget = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)

	local startCFrame
	if (flatTarget - startPos).Magnitude > 0.001 then
		startCFrame = CFrame.lookAt(startPos, flatTarget)
	else
		startCFrame = CFrame.new(startPos)
	end

	local targetCFrame = CFrame.lookAt(targetPos, targetPos + areaPart.CFrame.LookVector)
	local distance = math.abs(landingZ - backZ)
	local luck = (normalized ^ CONFIG.LUCK_EXPONENT) * CONFIG.MAX_LUCK

	return {
		StartCFrame = startCFrame,
		StartPosition = startPos,

		TargetCFrame = targetCFrame,
		TargetPosition = targetPos,

		ControlPosition = (startPos + targetPos) / 2 + Vector3.new(0, math.clamp(distance * 0.35, 16, 120), 0),

		Distance = distance,
		Luck = luck,
		Normalized = normalized,
		BarMultiplier = mult,
		Lane = lane,
	}
end

function KickCalculator.Preview(hitPower, barValue)
	return clamp(normalizePower(hitPower) * barMultiplier(barValue), 0, 1)
end

function KickCalculator.GetPowerFromData(configOrEconomy, data)
	local economy = getEconomy(configOrEconomy)

	if not data then
		return economy.StartingKickPower or 1
	end

	return math.max(data.HitPower or data.KickPower or economy.StartingKickPower or 1, 1)
end

function KickCalculator.GetDistance(configOrEconomy, kickPower)
	local kick = getKickConfig(configOrEconomy)

	kickPower = math.max(kickPower or 1, 1)

	local baseDistance = kick.BaseDistance or 35
	local distancePerPower = kick.DistancePerPower or 3.5
	local maxDistance = kick.MaxDistance or 250

	return math.clamp(baseDistance + kickPower * distancePerPower, baseDistance, maxDistance)
end

function KickCalculator.GetArcHeight(configOrEconomy, kickPower)
	local kick = getKickConfig(configOrEconomy)

	kickPower = math.max(kickPower or 1, 1)

	local baseArcHeight = kick.BaseArcHeight or 16
	local arcHeightPerPower = kick.ArcHeightPerPower or 0.35
	local maxArcHeight = kick.MaxArcHeight or 80

	return math.clamp(baseArcHeight + kickPower * arcHeightPerPower, baseArcHeight, maxArcHeight)
end

function KickCalculator.GetCashReward(configOrEconomy, kickPower, cashMultiplier)
	local kick = getKickConfig(configOrEconomy)

	kickPower = math.max(kickPower or 1, 1)
	cashMultiplier = math.max(cashMultiplier or 1, 1)

	local baseReward = kick.BaseReward or 10
	local rewardPerPower = kick.RewardPerPower or 3

	return math.max(1, math.floor((baseReward + kickPower * rewardPerPower) * cashMultiplier + 0.5))
end

function KickCalculator.GetPowerGain(configOrEconomy)
	local kick = getKickConfig(configOrEconomy)

	return math.max(kick.PowerGainPerHit or 1, 0)
end

function KickCalculator.SampleQuadraticBezier(startPosition, controlPosition, targetPosition, alpha)
	alpha = math.clamp(alpha, 0, 1)

	local a = startPosition:Lerp(controlPosition, alpha)
	local b = controlPosition:Lerp(targetPosition, alpha)

	return a:Lerp(b, alpha)
end

return KickCalculator