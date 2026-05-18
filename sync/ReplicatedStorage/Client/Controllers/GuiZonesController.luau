local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local GuiZonesController = Framework:CreateController("GuiZonesController")

local function getZonePlus()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local sharedPackages = shared and shared:FindFirstChild("Packages")
	local directPackages = ReplicatedStorage:FindFirstChild("Packages")
	local module = (sharedPackages and sharedPackages:FindFirstChild("ZonePlus"))
		or (directPackages and directPackages:FindFirstChild("ZonePlus"))

	assert(module and module:IsA("ModuleScript"), "[GuiZonesController] Missing ZonePlus ModuleScript")

	return require(module)
end

function GuiZonesController:Initialize()
	self.GuiController = Framework.Utils.GuiController
	self.ZonePlus = getZonePlus()
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

function GuiZonesController:_bindGuiZone(zonesFolder, zonePartName, guiName)
	local zonePart = zonesFolder:WaitForChild(zonePartName, 10)

	if not zonePart then
		warn(`[GuiZonesController] Missing zone part: {zonePartName}`)
		return
	end

	local screenGui = self.GuiController:GetGui(guiName)

	if not screenGui then
		warn(`[GuiZonesController] Missing ScreenGui: {guiName}`)
		return
	end

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
end

return GuiZonesController
