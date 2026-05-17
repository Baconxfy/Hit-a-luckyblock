--[[ 🎉 Dev(s)
	The_NetDev (josdev)
]]


--| Services |--
local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")

--| Local Functions |--
local function pagesToArray(pages)
	if not pages then return nil end
	
	local array = {}
	while true do
		for _, v in ipairs(pages:GetCurrentPage()) do
			table.insert(array, v)
		end
		if pages.IsFinished then
			break
		end
		pages:AdvanceToNextPageAsync()
	end
	return array
end

local module = {} --[ MODULE START HERE ]--

function module.getGroupInfo(groupId:number)
	local work, result = pcall(function()
		return GroupService:GetGroupInfoAsync(groupId)
	end)
	if not work then
		warn(result)
		result = nil
	end
	return result
end

function module.getGroupAllies(groupId:number)
	local work, result = pcall(function()
		return GroupService:GetAlliesAsync(groupId)
	end)
	if not work then
		warn(result)
		result = nil		
	end
	
	return pagesToArray(result)
	
end

function module.getGroupEnemies(groupId:number)
	local work, result = pcall(function()
		return GroupService:GetEnemiesAsync(groupId)
	end)
	if not work then
		warn(result)
		result = nil		
	end

	return pagesToArray(result)

end

function module.getPlayerStatusInGroup(player:Player, groupId:number)
	local work, result = pcall(function()
		if not player:IsInGroup(groupId) then return nil end
		return {
			Rank = player:GetRankInGroup(groupId),
			Role = player:GetRoleInGroup(groupId),
		}
	end)
	
	if not work then
		warn(result)
		result = nil
	end
	
	return result
	
end

return module
