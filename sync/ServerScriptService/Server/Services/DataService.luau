local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local DataService = Framework:CreateService("DataService")

local Players = game:GetService("Players")
local ProfileStore = Framework.Packages.ProfileStore

local ProfileTemplate = {
	Cash = 0,
	Rebirths = 0,
	LastFreeShopClaim = 0,
	Upgrades = {
		Speed = 0,
		Jump = 0,
	},
	Plot = {
		Floor2 = {},
		Floor3 = {},
	}
}

local GameProfileStore = ProfileStore.New("PlayerData_v1", ProfileTemplate)

DataService.Profiles = {}

function DataService:PlayerAdded(player)
	local profile = GameProfileStore:StartSessionAsync("Player_" .. player.UserId)
	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile.OnSessionEnd:Connect(function()
			self.Profiles[player] = nil
			player:Kick("Your profile has been loaded on another server. Please rejoin.")
		end)
		
		if player:IsDescendantOf(Players) then
			self.Profiles[player] = profile
			
			-- Create leaderstats for the player
			local leaderstats = Instance.new("Folder")
			leaderstats.Name = "leaderstats"
			
			local cashVal = Instance.new("NumberValue")
			cashVal.Name = "Cash"
			cashVal.Value = profile.Data.Cash
			cashVal.Parent = leaderstats
			
			-- Sync leaderstats changes to profile data
			cashVal.Changed:Connect(function(newVal)
				profile.Data.Cash = newVal
			end)
			
			leaderstats.Parent = player
			player:SetAttribute("DataLoaded", true)
		else
			profile:EndSession()
		end
	else
		player:Kick("Failed to load profile. Please rejoin.")
	end
end

function DataService:Start()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:PlayerAdded(player)
		end)
	end
	
	Players.PlayerAdded:Connect(function(player)
		self:PlayerAdded(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		local profile = self.Profiles[player]
		if profile ~= nil then
			profile:EndSession()
		end
	end)
end

function DataService:GetProfile(player)
	return self.Profiles[player]
end

return DataService
