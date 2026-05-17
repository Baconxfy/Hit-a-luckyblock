local Framework: any = require(game:GetService("ReplicatedStorage").Framework :: ModuleScript)

local BrainrotUpgradeService = Framework:CreateService("BrainrotUpgradeService")

function BrainrotUpgradeService:Initialize()
	self.Locks = {}
end

function BrainrotUpgradeService:GetLockKey(player: Player, padIndex: number): string
	return ("%d:%d"):format(player.UserId, padIndex)
end

function BrainrotUpgradeService:GetPad(player: Player, padIndex: number)
	local base = Framework:GetService("BaseService"):GetBaseFromPlayer(player)
	if not base or base.Owner ~= player then
		return nil
	end

	return base:GetPad(padIndex)
end

function BrainrotUpgradeService:GetPadUpgradeState(player: Player, padIndex: number)
	local pad = self:GetPad(player, math.floor(tonumber(padIndex) or 0))
	if not pad or not pad.GetBrainrotUpgradeState then
		return {
			Ok = false,
			Reason = "NoPad",
		}
	end

	return pad:GetBrainrotUpgradeState(player)
end

function BrainrotUpgradeService:UpgradePadBrainrot(player: Player, padIndex: number)
	padIndex = math.floor(tonumber(padIndex) or 0)
	local key = self:GetLockKey(player, padIndex)
	if self.Locks[key] then
		return self:GetPadUpgradeState(player, padIndex)
	end

	self.Locks[key] = true
	local ok, state = pcall(function()
		local pad = self:GetPad(player, padIndex)
		if not pad or not pad.UpgradeBrainrot then
			return {
				Ok = false,
				Reason = "NoPad",
			}
		end

		return pad:UpgradeBrainrot(player)
	end)
	self.Locks[key] = nil

	if ok then
		return state
	end

	warn(("[BrainrotUpgradeService] Upgrade failed for %s pad %d: %s"):format(player.Name, padIndex, tostring(state)))
	return {
		Ok = false,
		Reason = "Error",
	}
end

function BrainrotUpgradeService.Client:GetPadUpgradeState(player: Player, padIndex: number)
	return self:GetPadUpgradeState(player, padIndex)
end

function BrainrotUpgradeService.Client:UpgradePadBrainrot(player: Player, padIndex: number)
	return self:UpgradePadBrainrot(player, padIndex)
end

return BrainrotUpgradeService
