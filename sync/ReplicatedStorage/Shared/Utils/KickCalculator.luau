local KickCalculator = {}

local function getEconomy(configOrEconomy)
	if configOrEconomy.Economy then
		return configOrEconomy.Economy
	end

	return configOrEconomy
end

local function getKickConfig(configOrEconomy)
	return getEconomy(configOrEconomy).KickPower
end

function KickCalculator.GetPowerFromData(configOrEconomy, data)
	local economy = getEconomy(configOrEconomy)

	if not data then
		return economy.StartingKickPower or 1
	end

	return math.max(data.KickPower or economy.StartingKickPower or 1, 1)
end

function KickCalculator.GetDistance(configOrEconomy, kickPower)
	local kick = getKickConfig(configOrEconomy)

	kickPower = math.max(kickPower or 1, 1)

	local distance = kick.BaseDistance + kickPower * kick.DistancePerPower

	return math.clamp(distance, kick.BaseDistance, kick.MaxDistance)
end

function KickCalculator.GetArcHeight(configOrEconomy, kickPower)
	local kick = getKickConfig(configOrEconomy)

	kickPower = math.max(kickPower or 1, 1)

	local height = kick.BaseArcHeight + kickPower * kick.ArcHeightPerPower

	return math.clamp(height, kick.BaseArcHeight, kick.MaxArcHeight)
end

function KickCalculator.GetCashReward(configOrEconomy, kickPower, cashMultiplier)
	local kick = getKickConfig(configOrEconomy)

	kickPower = math.max(kickPower or 1, 1)
	cashMultiplier = math.max(cashMultiplier or 1, 1)

	return math.max(1, math.floor((kick.BaseReward + kickPower * kick.RewardPerPower) * cashMultiplier + 0.5))
end

function KickCalculator.GetPowerGain(configOrEconomy)
	local kick = getKickConfig(configOrEconomy)

	return math.max(kick.PowerGainPerHit or 1, 0)
end

function KickCalculator.GetFlight(configOrEconomy, startPosition, direction, kickPower)
	local distance = KickCalculator.GetDistance(configOrEconomy, kickPower)
	local arcHeight = KickCalculator.GetArcHeight(configOrEconomy, kickPower)

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.001 then
		flatDirection = Vector3.zAxis * -1
	else
		flatDirection = flatDirection.Unit
	end

	local targetPosition = startPosition + flatDirection * distance

	return {
		StartPosition = startPosition,
		TargetPosition = targetPosition,
		ControlPosition = (startPosition + targetPosition) * 0.5 + Vector3.yAxis * arcHeight,
		Distance = distance,
		ArcHeight = arcHeight,
	}
end

function KickCalculator.SampleQuadraticBezier(startPosition, controlPosition, targetPosition, alpha)
	alpha = math.clamp(alpha, 0, 1)

	local a = startPosition:Lerp(controlPosition, alpha)
	local b = controlPosition:Lerp(targetPosition, alpha)

	return a:Lerp(b, alpha)
end

return KickCalculator