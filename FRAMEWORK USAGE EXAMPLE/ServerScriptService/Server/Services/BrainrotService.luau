local Framework: any = require(game:GetService("ReplicatedStorage").Framework :: ModuleScript)

local BrainrotService = Framework:CreateService("BrainrotService")

function BrainrotService:Initialize()
	self.UpgradeLocks = {}
end

function BrainrotService:GetUpgradeLockKey(player: Player, padIndex: number): string
	return ("%d:%d"):format(player.UserId, padIndex)
end

function BrainrotService:GetPlayerPad(player: Player, padIndex: number)
	local base = Framework:GetService("BaseService"):GetBaseFromPlayer(player)
	if not base or base.Owner ~= player then
		return nil
	end

	return base:GetPad(padIndex)
end

function BrainrotService:GetPadUpgradeState(player: Player, padIndex: number)
	local pad = self:GetPlayerPad(player, math.floor(tonumber(padIndex) or 0))
	if not pad or not pad.GetBrainrotUpgradeState then
		return {
			Ok = false,
			Reason = "NoPad",
		}
	end

	return pad:GetBrainrotUpgradeState(player)
end

function BrainrotService:UpgradePadBrainrot(player: Player, padIndex: number)
	padIndex = math.floor(tonumber(padIndex) or 0)
	local key = self:GetUpgradeLockKey(player, padIndex)
	if self.UpgradeLocks[key] then
		return self:GetPadUpgradeState(player, padIndex)
	end

	self.UpgradeLocks[key] = true
	local ok, state = pcall(function()
		local pad = self:GetPlayerPad(player, padIndex)
		if not pad or not pad.UpgradeBrainrot then
			return {
				Ok = false,
				Reason = "NoPad",
			}
		end

		return pad:UpgradeBrainrot(player)
	end)
	self.UpgradeLocks[key] = nil

	if ok then
		return state
	end

	warn(("[BrainrotService] Upgrade failed for %s pad %d: %s"):format(player.Name, padIndex, tostring(state)))
	return {
		Ok = false,
		Reason = "Error",
	}
end

function BrainrotService.Client:GetPadUpgradeState(player: Player, padIndex: number)
	return self:GetPadUpgradeState(player, padIndex)
end

function BrainrotService.Client:UpgradePadBrainrot(player: Player, padIndex: number)
	return self:UpgradePadBrainrot(player, padIndex)
end

return BrainrotService
