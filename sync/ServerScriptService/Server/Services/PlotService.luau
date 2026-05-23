local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local PlotService = Framework:CreateService("PlotService")

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local function FormatNumberWithCommas(number)
	local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
	int = int:reverse():gsub("(%d%d%d)", "%1,")
	return minus .. int:reverse():gsub("^,", "") .. fraction
end

function PlotService:Initialize()
	self.PlotVisibilityUtil = require(ServerScriptService.Server.Utils.PlotVisibilityUtil)
	
	self._PlotsOwner = {}
	self._PlayersPlot = {}
	
	self.PlotsFolder = workspace:WaitForChild("Plots")
	
	for _, plotModel in ipairs(self.PlotsFolder:GetChildren()) do
		self._PlotsOwner[plotModel] = nil
		task.spawn(function() self:ResetPlot(plotModel) end)
	end
end

function PlotService:Start()
	self.DataService = Framework:GetService("DataService")
	
	Players.PlayerAdded:Connect(function(player: Player) 
		self:AssignPlot(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player: Player)
		self:ReleasePlot(player)
	end)
end

function PlotService:ResetPlot(PlotModel: Model)
	self.PlotVisibilityUtil.HideAll(PlotModel)

	local Floor1 = PlotModel:WaitForChild("Floor1")

	local CarpetPart = Floor1:WaitForChild("Carpet")
	local CarpetAttachment = CarpetPart:FindFirstChildOfClass("Attachment")
	if CarpetAttachment then
		local CashMultiGui = CarpetAttachment:FindFirstChildOfClass("BillboardGui")
		if CashMultiGui then
			local Frame = CashMultiGui:FindFirstChildOfClass("Frame")
			if Frame then
				local CostLabel = Frame:FindFirstChild("Cost")
				local NameLabel = Frame:FindFirstChild("Name")
				if NameLabel then NameLabel.Visible = false end
				if CostLabel then CostLabel.Visible = false end
			end
		end
	end

	local PlotSign = PlotModel:WaitForChild("PlotSign")
	local FrontPart = PlotSign:FindFirstChild("FrontPart")
	if FrontPart then
		local SurfaceGui = FrontPart:FindFirstChildOfClass("SurfaceGui")
		if SurfaceGui then
			local Frame = SurfaceGui:FindFirstChildOfClass("Frame")
			if Frame then
				local PfpHolder = Frame:FindFirstChild("PfpHolder")
				local CashIcon = Frame:FindFirstChild("CashIcon")
				local LikeIcon = Frame:FindFirstChild("LikeIcon")
				local UsernameLabel = Frame:FindFirstChild("Username")
				local DisplayNameLabel = Frame:FindFirstChild("DisplayName")
				local LikesLabel = Frame:FindFirstChild("Likes")
				local MoneyLabel = Frame:FindFirstChild("Money")
				
				if CashIcon then CashIcon.Visible = false end
				if LikeIcon then LikeIcon.Visible = false end
				if PfpHolder then PfpHolder.Image = "" end
				if UsernameLabel then UsernameLabel.Text = "" end
				if DisplayNameLabel then DisplayNameLabel.Text = "" end
				if MoneyLabel then MoneyLabel.Text = "" end
				if LikesLabel then LikesLabel.Text = "" end
			end
		end
	end

	local hasOwner = PlotModel:FindFirstChild("Owner")
	if hasOwner then
		hasOwner:Destroy()
	end
end

function PlotService:LoadPlot(PlotModel: Model, Player: Player)
	local OwnerValue = Instance.new("ObjectValue")
	OwnerValue.Name = "Owner"
	OwnerValue.Value = Player
	OwnerValue.Parent = PlotModel

	Player:GetAttributeChangedSignal("DataLoaded"):Wait()

	if not Player.Parent then return end

	local RebirthsValue = self.DataService:GetData(Player.UserId, "Rebirths") or 0
	local PlotData = self.DataService:GetData(Player.UserId, "Plot") or {}

	local Floor2 = PlotData.Floor2
	if Floor2 then
		self.PlotVisibilityUtil.ShowFloor(PlotModel, "Floor2")
		for slotName, slotVal in pairs(Floor2) do
			if typeof(slotVal) == "string" then
				self.PlotVisibilityUtil.ShowSlot(PlotModel, "Floor2", slotName)
			end
		end

		local Floor3 = PlotData.Floor3
		if Floor3 then
			self.PlotVisibilityUtil.ShowFloor(PlotModel, "Floor3")
			for slotName, slotVal in pairs(Floor3) do
				if typeof(slotVal) == "string" then
					self.PlotVisibilityUtil.ShowSlot(PlotModel, "Floor3", slotName)
				end
			end
		end
	end
	
	local Floor1 = PlotModel:WaitForChild("Floor1")
	
	local CarpetPart = Floor1:WaitForChild("Carpet")
	local CarpetAttachment = CarpetPart:FindFirstChildOfClass("Attachment")
	if CarpetAttachment then
		local CashMultiGui = CarpetAttachment:FindFirstChildOfClass("BillboardGui")
		if CashMultiGui then
			local Frame = CashMultiGui:FindFirstChildOfClass("Frame")
			if Frame then
				local CostLabel = Frame:FindFirstChild("Cost")
				local NameLabel = Frame:FindFirstChild("Name")

				if NameLabel then NameLabel.Visible = true end
				if CostLabel then 
					CostLabel.Text = "x" .. FormatNumberWithCommas(RebirthsValue)
					CostLabel.Visible = true 
				end
			end
		end
	end
	
	local PlotSign = PlotModel:WaitForChild("PlotSign")
	local FrontPart = PlotSign:FindFirstChild("FrontPart")
	if FrontPart then
		local SurfaceGui = FrontPart:FindFirstChildOfClass("SurfaceGui")
		if SurfaceGui then
			local Frame = SurfaceGui:FindFirstChildOfClass("Frame")
			if Frame then
				local PfpHolder = Frame:FindFirstChild("PfpHolder")
				local CashIcon = Frame:FindFirstChild("CashIcon")
				local LikeIcon = Frame:FindFirstChild("LikeIcon")
				
				local UsernameLabel = Frame:FindFirstChild("Username")
				local DisplayNameLabel = Frame:FindFirstChild("DisplayName")
				local LikesLabel = Frame:FindFirstChild("Likes")
				local MoneyLabel = Frame:FindFirstChild("Money")
				
				if CashIcon then CashIcon.Visible = false end
				if LikeIcon then LikeIcon.Visible = false end
				
				local workProfile, profileImage = pcall(function()
					return Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
				end)
				
				if workProfile and PfpHolder then
					PfpHolder.Image = profileImage
				end
				
				if UsernameLabel then UsernameLabel.Text = "@" .. Player.Name end
				if DisplayNameLabel then DisplayNameLabel.Text = Player.DisplayName end
				if MoneyLabel then MoneyLabel.Text = "$TotalMoney/s" end
				if LikesLabel then LikesLabel.Text = "KeepLikes?" end
			end
		end
	end
	
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local HRP = Character:WaitForChild("HumanoidRootPart")
	
	local PlayerSpawn = PlotModel:WaitForChild("PlayerSpawn")
	HRP.CFrame = PlayerSpawn.CFrame
end

function PlotService:GetPlotOwner(PlotModel: Model): Player?
	return self._PlotsOwner[PlotModel]
end

function PlotService:GetPlayerPlot(Player: Player): Model?
	return self._PlayersPlot[Player]
end

function PlotService:AssignPlot(Player: Player): Model?
	local hasPlot = self._PlayersPlot[Player]
	if hasPlot then return hasPlot end

	local selectedPlot = nil

	while not selectedPlot do
		if not Player.Parent then return nil end

		for _, plotModel in pairs(self.PlotsFolder:GetChildren()) do
			if not self._PlotsOwner[plotModel] then
				self._PlotsOwner[plotModel] = Player
				self._PlayersPlot[Player] = plotModel
				selectedPlot = plotModel
				break
			end
		end

		if not selectedPlot then
			task.wait(1)
		end
	end

	local PlotValue = Instance.new("ObjectValue")
	PlotValue.Name = "Plot"
	PlotValue.Value = selectedPlot
	PlotValue.Parent = Player

	task.spawn(function()
		self:LoadPlot(selectedPlot, Player)
	end)

	return selectedPlot
end

function PlotService:ReleasePlot(Player: Player)
	local plotModel = self._PlayersPlot[Player]
	if plotModel then
		self._PlotsOwner[plotModel] = nil
		self._PlayersPlot[Player] = nil
		task.defer(function() self:ResetPlot(plotModel) end)
	end
end

return PlotService
