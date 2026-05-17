local KickCalculator = {}

local CONFIG = {
	MIN_POWER = 0,
	MAX_POWER = 100000, 
	POWER_EXPONENT = 0.6,
	BAR_MIN_MULT = 0.1,  -- BAD hit = 10% of distance
	BAR_MAX_MULT = 1.2,  -- PERFECT hit = 120% (allows exceeding base power at high accuracy)
	MAX_LUCK = 100,
	LUCK_EXPONENT = 1.2,
	Z_JITTER_MAX_STUDS = 10,
	X_JITTER_MAX_STUDS = 4,
	BORDER_MARGIN = 5,
	FRONT_IS_POSITIVE_Z = true,
	LANDING_Y_OFFSET = 2,
}

local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function normalizePower(hitPower)
	local p = clamp(hitPower, CONFIG.MIN_POWER, CONFIG.MAX_POWER)
	local ratio = p / CONFIG.MAX_POWER
	return ratio ^ CONFIG.POWER_EXPONENT
end

local function barMultiplier(barValue)
	local bar = clamp(barValue, 0, 1)
	return CONFIG.BAR_MIN_MULT + (CONFIG.BAR_MAX_MULT - CONFIG.BAR_MIN_MULT) * bar
end

export type KickResult = {
	StartCFrame : CFrame,
	StartPosition : Vector3,
	TargetCFrame : CFrame,
	TargetPosition : Vector3,
	Distance : number,
	Luck : number,
	Normalized : number,
	BarMultiplier : number,
	Lane : number,
}

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
	local backZ, frontZ
	if CONFIG.FRONT_IS_POSITIVE_Z then
		backZ, frontZ = -edge, edge
	else
		backZ, frontZ = edge, -edge
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

return KickCalculator
