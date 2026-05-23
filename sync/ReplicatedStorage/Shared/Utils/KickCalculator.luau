local KickCalculator = {}

local CONFIG = {
	MAX_POWER = 100000,
	POWER_EXPONENT = 0.6,

	-- HitPower expands the maximum timing range. Timing still works at zero power.
	ZERO_POWER_MAX_RUNWAY_FRACTION = 0.35,
	ZERO_POWER_MAX_DISTANCE_CAP = 400,
	MIN_DISTANCE = 30,
	MIN_RUNWAY_FRACTION = 0.08,

	BORDER_MARGIN = 5,
	LANDING_Y_OFFSET = 2,

	MAX_LUCK = 100,
	LUCK_EXPONENT = 1.2,
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

local function lerp(a, b, alpha)
	return a + (b - a) * alpha
end

local function normalizeBar(barValue)
	return clamp(tonumber(barValue) or 0, 0, 1)
end

local function normalizePower(hitPower)
	local power = clamp(tonumber(hitPower) or 0, 0, CONFIG.MAX_POWER)
	local ratio = power / CONFIG.MAX_POWER
	return ratio ^ CONFIG.POWER_EXPONENT
end

local function getAxisEdges(halfLength)
	local edge = math.max(halfLength - CONFIG.BORDER_MARGIN, 0)
	return -edge, edge
end

local function getRunway(playerAxisPosition, halfLength)
	local negativeEdge, positiveEdge = getAxisEdges(halfLength)
	if math.abs(playerAxisPosition - negativeEdge) <= math.abs(playerAxisPosition - positiveEdge) then
		return negativeEdge, positiveEdge
	end

	return positiveEdge, negativeEdge
end

local function getLane(playerLocal, halfX, halfZ, useXAxis)
	if useXAxis then
		local minZ, maxZ = getAxisEdges(halfZ)
		return clamp(playerLocal.Z, minZ, maxZ)
	end

	local minX, maxX = getAxisEdges(halfX)
	return clamp(playerLocal.X, minX, maxX)
end

local function getMinDistance(runwayLength)
	return math.min(CONFIG.MIN_DISTANCE, runwayLength * CONFIG.MIN_RUNWAY_FRACTION)
end

local function getZeroPowerMaxDistance(runwayLength, minDistance)
	local fractionDistance = runwayLength * CONFIG.ZERO_POWER_MAX_RUNWAY_FRACTION
	local cappedDistance = math.min(fractionDistance, CONFIG.ZERO_POWER_MAX_DISTANCE_CAP)
	return clamp(cappedDistance, minDistance, runwayLength)
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

function KickCalculator.Compute(hitPower, barValue, rootPart, areaPart)
	local size = areaPart.Size
	local halfX = size.X / 2
	local halfZ = size.Z / 2
	local playerLocal = areaPart.CFrame:PointToObjectSpace(rootPart.Position)
	local useXAxis = size.X >= size.Z
	local runwayPlayerPosition = if useXAxis then playerLocal.X else playerLocal.Z
	local runwayHalfLength = if useXAxis then halfX else halfZ
	local back, front = getRunway(runwayPlayerPosition, runwayHalfLength)
	local lane = getLane(playerLocal, halfX, halfZ, useXAxis)
	local runway = front - back
	local runwayLength = math.abs(runway)
	local runwayDirection = if runway >= 0 then 1 else -1
	local minDistance = getMinDistance(runwayLength)

	local bar = normalizeBar(barValue)
	local power = normalizePower(hitPower)
	local zeroPowerMaxDistance = getZeroPowerMaxDistance(runwayLength, minDistance)
	local maxDistance = lerp(zeroPowerMaxDistance, runwayLength, power)
	local distance = clamp(lerp(minDistance, maxDistance, bar), 0, runwayLength)
	local normalized = if runwayLength > 0 then distance / runwayLength else 0

	local landingAxisPosition = back + distance * runwayDirection
	local landingX = if useXAxis then landingAxisPosition else lane
	local landingZ = if useXAxis then lane else landingAxisPosition
	local localLanding = Vector3.new(landingX, CONFIG.LANDING_Y_OFFSET, landingZ)
	local targetPosition = areaPart.CFrame:PointToWorldSpace(localLanding)

	local startX = if useXAxis then back else lane
	local startZ = if useXAxis then lane else back
	local localStart = Vector3.new(startX, playerLocal.Y, startZ)
	local startPosition = areaPart.CFrame:PointToWorldSpace(localStart)
	local flatTarget = Vector3.new(targetPosition.X, startPosition.Y, targetPosition.Z)
	local flatTravel = flatTarget - startPosition
	local flatDirection = if flatTravel.Magnitude > 0.001 then flatTravel.Unit else areaPart.CFrame.LookVector
	local startCFrame = if flatTravel.Magnitude > 0.001
		then CFrame.lookAt(startPosition, startPosition + flatDirection)
		else CFrame.new(startPosition)
	local targetCFrame = CFrame.lookAt(targetPosition, targetPosition + flatDirection)

	return {
		StartCFrame = startCFrame,
		StartPosition = startPosition,
		TargetCFrame = targetCFrame,
		TargetPosition = targetPosition,
		Distance = distance,
		Luck = (normalized ^ CONFIG.LUCK_EXPONENT) * CONFIG.MAX_LUCK,
		Normalized = normalized,
		BarMultiplier = bar,
		Lane = lane,
	}
end

function KickCalculator.Preview(hitPower, barValue)
	local bar = normalizeBar(barValue)
	local power = normalizePower(hitPower)
	return clamp(lerp(CONFIG.ZERO_POWER_MAX_RUNWAY_FRACTION, 1, power) * bar, 0, 1)
end

return KickCalculator
