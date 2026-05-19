local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local GuiZonesController = Framework:CreateController("GuiZonesController")

local function getZonePlus()
	local packages = ReplicatedStorage:WaitForChild("Packages")
	return require(packages:WaitForChild("ZonePlus"))
end

function GuiZonesController:Initialize()
	self.Player = Players.LocalPlayer
	self.GuiController = Framework.Utils.GuiController
	self.ZonePlus = getZonePlus()
	self._connections = {}
	self._zones = {}
end

function GuiZonesController:Start()
	local zonesFolder = workspace:WaitForChild("Zones", 120)
	if not zonesFolder then
		warn("[GuiZonesController] Missing workspace.Zones")
		return
	end

	self:_bindGuiZone(zonesFolder, "ShowWeightUI", "WeightUI")
	self:_bindGuiZone(zonesFolder, "ShowSpeedUpgrades", "SpeedUpgrades")
end

function GuiZonesController:_getScreenGuiWhenAvailable(guiName, callback)
	local playerGui = self.Player:WaitForChild("PlayerGui")

	local existingGui = self.GuiController:GetGui(guiName)
	if existingGui then
		callback(existingGui)
		return
	end

	warn(`[GuiZonesController] Waiting for ScreenGui: {guiName}`)

	local connection
	connection = playerGui.ChildAdded:Connect(function(child)
		if child.Name ~= guiName or not child:IsA("ScreenGui") then
			return
		end

		if connection then
			connection:Disconnect()
		end

		self.GuiController:RegisterGui(child)
		callback(child)
	end)

	table.insert(self._connections, connection)
end

function GuiZonesController:_bindGuiZone(zonesFolder, zonePartName, guiName)
	local zonePart = zonesFolder:WaitForChild(zonePartName, 10)
	if not zonePart then
		warn(`[GuiZonesController] Missing zone part: {zonePartName}`)
		return
	end

	self:_getScreenGuiWhenAvailable(guiName, function(screenGui)
		local mainFrame = self.GuiController:GetMainFrame(screenGui)
		if not mainFrame then
			warn(`[GuiZonesController] Missing main frame for gui: {guiName}`)
			return
		end

		local zone = self.ZonePlus.new(zonePart)
		table.insert(self._zones, zone)

		zone.localPlayerEntered:Connect(function()
			self.GuiController:OpenMainFrame(mainFrame)
		end)

		zone.localPlayerExited:Connect(function()
			if self.GuiController.CurrentMainFrame == mainFrame then
				self.GuiController:CloseMainFrame(mainFrame)
			end
		end)
	end)
end

return GuiZonesController