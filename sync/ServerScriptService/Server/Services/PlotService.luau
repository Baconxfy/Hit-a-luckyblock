local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local PlotService = Framework:CreateService("PlotService")

local PlotVisibilityUtil = Framework.Utils.PlotVisibilityUtil
local FormatUtil = Framework.Utils.FormatUtil

local function findFrame(gui: Instance?): Frame?
	if not gui then
		return nil
	end

	return gui:FindFirstChildOfClass("Frame")
end

local function setTextIfExists(parent: Instance?, name: string, text: string)
	if not parent then
		return
	end

	local label = parent:FindFirstChild(name)

	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function setVisibleIfExists(parent: Instance?, name: string, visible: boolean)
	if not parent then
		return
	end

	local object = parent:FindFirstChild(name)

	if object and object:IsA("GuiObject") then
		object.Visible = visible
	end
end

function PlotService:Initialize()
	self.PlotVisibilityUtil = PlotVisibilityUtil
	self.FormatUtil = FormatUtil
	self.DataService = Framework:GetService("DataService")

	self._PlotsOwner = {}
	self._PlayersPlot = {}

	self.PlotsFolder = workspace:WaitForChild("Plots")

	for _, plotModel in ipairs(self.PlotsFolder:GetChildren()) do
		if plotModel:IsA("Model") then
			task.spawn(function()
				self:ResetPlot(plotModel)
			end)
		end
	end
end

function PlotService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:AssignPlot(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:AssignPlot(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:ReleasePlot(player)
	end)
end

function PlotService:_getCarpetFrame(plotModel: Model): Frame?
	local floor1 = plotModel:FindFirstChild("Floor1")

	if not floor1 then
		return nil
	end

	local carpetPart = floor1:FindFirstChild("Carpet")

	if not carpetPart then
		return nil
	end

	local carpetAttachment = carpetPart:FindFirstChildOfClass("Attachment")

	if not carpetAttachment then
		return nil
	end

	local cashMultiGui = carpetAttachment:FindFirstChildOfClass("BillboardGui")

	return findFrame(cashMultiGui)
end

function PlotService:_getSignFrame(plotModel: Model): Frame?
	local plotSign = plotModel:FindFirstChild("PlotSign")

	if not plotSign then
		return nil
	end

	local frontPart = plotSign:FindFirstChild("FrontPart")

	if not frontPart then
		return nil
	end

	local surfaceGui = frontPart:FindFirstChildOfClass("SurfaceGui")

	return findFrame(surfaceGui)
end

function PlotService:ResetPlot(plotModel: Model)
	self.PlotVisibilityUtil.HideAll(plotModel)

	local carpetFrame = self:_getCarpetFrame(plotModel)

	setVisibleIfExists(carpetFrame, "Name", false)
	setVisibleIfExists(carpetFrame, "Cost", false)

	local signFrame = self:_getSignFrame(plotModel)

	setVisibleIfExists(signFrame, "CashIcon", false)
	setVisibleIfExists(signFrame, "LikeIcon", false)

	local pfpHolder = signFrame and signFrame:FindFirstChild("PfpHolder")

	if pfpHolder and pfpHolder:IsA("ImageLabel") then
		pfpHolder.Image = ""
	end

	setTextIfExists(signFrame, "Username", "")
	setTextIfExists(signFrame, "DisplayName", "")
	setTextIfExists(signFrame, "Likes", "")
	setTextIfExists(signFrame, "Money", "")

	local ownerValue = plotModel:FindFirstChild("Owner")

	if ownerValue then
		ownerValue:Destroy()
	end
end

function PlotService:LoadPlot(plotModel: Model, player: Player)
	local existingOwner = plotModel:FindFirstChild("Owner")

	if existingOwner then
		existingOwner:Destroy()
	end

	local ownerValue = Instance.new("ObjectValue")
	ownerValue.Name = "Owner"
	ownerValue.Value = player
	ownerValue.Parent = plotModel

	if not player:GetAttribute("DataLoaded") then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	if not player.Parent then
		return
	end

	local profile = self.DataService:GetProfile(player)

	if not profile then
		return
	end

	local rebirthsValue = profile.Data.Rebirths or 0
	local plotData = profile.Data.Plot

	if plotData then
		local floor2 = plotData.Floor2

		if floor2 then
			self.PlotVisibilityUtil.ShowFloor(plotModel, "Floor2")

			for _, slotName in ipairs(floor2) do
				self.PlotVisibilityUtil.ShowSlot(plotModel, "Floor2", slotName)
			end
		end

		local floor3 = plotData.Floor3

		if floor3 then
			self.PlotVisibilityUtil.ShowFloor(plotModel, "Floor3")

			for _, slotName in ipairs(floor3) do
				self.PlotVisibilityUtil.ShowSlot(plotModel, "Floor3", slotName)
			end
		end
	end

	local carpetFrame = self:_getCarpetFrame(plotModel)

	setVisibleIfExists(carpetFrame, "Name", true)

	local costLabel = carpetFrame and carpetFrame:FindFirstChild("Cost")

	if costLabel and costLabel:IsA("TextLabel") then
		costLabel.Text = self.FormatUtil.FormatMultiplier(rebirthsValue)
		costLabel.Visible = true
	end

	local signFrame = self:_getSignFrame(plotModel)

	setVisibleIfExists(signFrame, "CashIcon", false)
	setVisibleIfExists(signFrame, "LikeIcon", false)

	local pfpHolder = signFrame and signFrame:FindFirstChild("PfpHolder")

	if pfpHolder and pfpHolder:IsA("ImageLabel") then
		local thumbOk, profileImage = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.AvatarBust,
				Enum.ThumbnailSize.Size420x420
			)
		end)

		if thumbOk then
			pfpHolder.Image = profileImage
		end
	end

	setTextIfExists(signFrame, "Username", "@" .. player.Name)
	setTextIfExists(signFrame, "DisplayName", player.DisplayName)
	setTextIfExists(signFrame, "Money", "")
	setTextIfExists(signFrame, "Likes", "")

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local playerSpawn = plotModel:WaitForChild("PlayerSpawn")

	humanoidRootPart.CFrame = playerSpawn.CFrame
end

function PlotService:GetPlotOwner(plotModel: Model): Player?
	return self._PlotsOwner[plotModel]
end

function PlotService:GetPlayerPlot(player: Player): Model?
	return self._PlayersPlot[player]
end

function PlotService:AssignPlot(player: Player): Model?
	local existingPlot = self._PlayersPlot[player]

	if existingPlot then
		return existingPlot
	end

	local selectedPlot = nil

	while not selectedPlot do
		if not player.Parent then
			return nil
		end

		for _, plotModel in ipairs(self.PlotsFolder:GetChildren()) do
			if not plotModel:IsA("Model") then
				continue
			end

			if not self._PlotsOwner[plotModel] then
				self._PlotsOwner[plotModel] = player
				self._PlayersPlot[player] = plotModel
				selectedPlot = plotModel
				break
			end
		end

		if not selectedPlot then
			task.wait(1)
		end
	end

	local oldPlotValue = player:FindFirstChild("Plot")

	if oldPlotValue then
		oldPlotValue:Destroy()
	end

	local plotValue = Instance.new("ObjectValue")
	plotValue.Name = "Plot"
	plotValue.Value = selectedPlot
	plotValue.Parent = player

	task.spawn(function()
		self:LoadPlot(selectedPlot, player)
	end)

	return selectedPlot
end

function PlotService:ReleasePlot(player: Player)
	local plotModel = self._PlayersPlot[player]

	self._PlayersPlot[player] = nil

	local plotValue = player:FindFirstChild("Plot")

	if plotValue then
		plotValue:Destroy()
	end

	if not plotModel then
		return
	end

	self._PlotsOwner[plotModel] = nil

	task.defer(function()
		self:ResetPlot(plotModel)
	end)
end

return PlotService