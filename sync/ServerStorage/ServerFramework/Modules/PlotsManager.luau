--< Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

--< Modules
local FormatUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("FormatUtil"))
local PlotVisibilityController = require(script:WaitForChild("PlotVisibilityController"))
local EzProfile = require(ServerStorage:WaitForChild("ServerPackages"):WaitForChild("EzProfile"))
local Blink = require(ReplicatedStorage:WaitForChild("Blink"):WaitForChild("Server"))

--< Workspace Variables
local PlotsFolder = workspace:WaitForChild("Plots")

--< Variables
local _PlotsOwner: {[Model]: Player?} = {}
local _PlayersPlot: {[Player]: Model} = {}

print(PlotVisibilityController.PlotsDictionary)

--< Helpers

local function ResetPlot(PlotModel: Model)
	PlotVisibilityController.HideAll(PlotModel)

	local Floor1 = PlotModel:WaitForChild("Floor1")

	-- Carpet (cash multiplier sign)
	local CarpetPart: BasePart = Floor1:WaitForChild("Carpet")
	local CarpetAttachment = CarpetPart:FindFirstChildOfClass("Attachment")
	if CarpetAttachment then
		local CashMultiGui = CarpetAttachment:FindFirstChildOfClass("BillboardGui")
		if CashMultiGui then
			local Frame = CashMultiGui:FindFirstChildOfClass("Frame")
			if Frame then
				
				local CostLabel :TextLabel = Frame:FindFirstChild("Cost")
				local NameLabel :TextLabel = Frame:FindFirstChild("Name")

				NameLabel.Visible = false
				CostLabel.Visible = false

			end
		end
	end

	-- Plot Sign (owner display)
	local PlotSign: Model = PlotModel:WaitForChild("PlotSign")
	local FrontPart: BasePart = PlotSign:FindFirstChild("FrontPart")
	if FrontPart then
		local SurfaceGui = FrontPart:FindFirstChildOfClass("SurfaceGui")
		if SurfaceGui then
			local Frame = SurfaceGui:FindFirstChildOfClass("Frame")
			if Frame then
				
				local PfpHolder: ImageLabel = Frame:FindFirstChild("PfpHolder")
				local CashIcon: ImageLabel = Frame:FindFirstChild("CashIcon")
				local LikeIcon: ImageLabel = Frame:FindFirstChild("LikeIcon")
				
				local UsernameLabel: TextLabel = Frame:FindFirstChild("Username")
				local DisplayNameLabel: TextLabel = Frame:FindFirstChild("DisplayName")
				local LikesLabel: TextLabel = Frame:FindFirstChild("Likes")
				local MoneyLabel: TextLabel = Frame:FindFirstChild("Money")
				
				CashIcon.Visible = false
				LikeIcon.Visible = false
				
				PfpHolder.Image = ""
				
				UsernameLabel.Text = ""
				DisplayNameLabel.Text = ""
				MoneyLabel.Text = ""
				LikesLabel.Text = ""
			end
		end
	end

	-- Remove owner reference
	local hasOwner = PlotModel:FindFirstChild("Owner")
	if hasOwner then
		hasOwner:Destroy()
	end
end


local function LoadPlot(PlotModel: Model, Player: Player)
	-- Mark ownership inside the plot
	local OwnerValue = Instance.new("ObjectValue")
	OwnerValue.Name = "Owner"
	OwnerValue.Value = Player
	OwnerValue.Parent = PlotModel

	Player:GetAttributeChangedSignal("DataLoaded"):Wait()

	-- Bail out if the player left during the wait
	if not Player.Parent then return end

	-- FIX: DataLoaded fires before EzProfile finishes populating the ProfileFolder
	-- (race between OnDataLoaded and FillFolder callbacks). Retry for up to 3s.
	local DataFolder
	for _ = 1, 30 do
		DataFolder = EzProfile:GetProfileFolder(Player)
		if DataFolder then break end
		task.wait(0.1)
	end

	if not DataFolder then
		warn("[LoadPlot] DataFolder not found for", Player.Name)
		Player:Kick()
		return
	end

	local RebirthsValue :NumberValue = DataFolder:WaitForChild("Rebirths")
	local PlotData: Folder = DataFolder:WaitForChild("Plot")

	-- Floor2
	local Floor2 = PlotData:FindFirstChild("Floor2")
	if Floor2 then
		PlotVisibilityController.ShowFloor(PlotModel, "Floor2")
		for _, slotVal in ipairs(Floor2:GetChildren()) do
			if slotVal:IsA("StringValue") then
				PlotVisibilityController.ShowSlot(PlotModel, "Floor2", slotVal.Name)
			end
		end

		-- Floor3 (only available if Floor2 is unlocked)
		local Floor3 = PlotData:FindFirstChild("Floor3")
		if Floor3 then
			PlotVisibilityController.ShowFloor(PlotModel, "Floor3")
			for _, slotVal in ipairs(Floor3:GetChildren()) do
				if slotVal:IsA("StringValue") then
					PlotVisibilityController.ShowSlot(PlotModel, "Floor3", slotVal.Name)
				end
			end
		end
	end
	
	local Floor1 = PlotModel:WaitForChild("Floor1")
	
	-- Carpet (cash multiplier sign)
	local CarpetPart: BasePart = Floor1:WaitForChild("Carpet")
	local CarpetAttachment = CarpetPart:FindFirstChildOfClass("Attachment")
	if CarpetAttachment then
		local CashMultiGui = CarpetAttachment:FindFirstChildOfClass("BillboardGui")
		if CashMultiGui then
			local Frame = CashMultiGui:FindFirstChildOfClass("Frame")
			if Frame then

				local CostLabel :TextLabel = Frame:FindFirstChild("Cost")
				local NameLabel :TextLabel = Frame:FindFirstChild("Name")

				NameLabel.Visible = true
				
				CostLabel.Text = `x{FormatUtil.FormatNumberWithCommas(RebirthsValue.Value)}`
				
				CostLabel.Visible = true

			end
		end
	end
	
	-- Plot Sign (owner display)
	local PlotSign: Model = PlotModel:WaitForChild("PlotSign")
	local FrontPart: BasePart = PlotSign:FindFirstChild("FrontPart")
	if FrontPart then
		local SurfaceGui = FrontPart:FindFirstChildOfClass("SurfaceGui")
		if SurfaceGui then
			local Frame = SurfaceGui:FindFirstChildOfClass("Frame")
			if Frame then
				local PfpHolder: ImageLabel = Frame:FindFirstChild("PfpHolder")
				local CashIcon: ImageLabel = Frame:FindFirstChild("CashIcon")
				local LikeIcon: ImageLabel = Frame:FindFirstChild("LikeIcon")
				
				local UsernameLabel: TextLabel = Frame:FindFirstChild("Username")
				local DisplayNameLabel: TextLabel = Frame:FindFirstChild("DisplayName")
				local LikesLabel: TextLabel = Frame:FindFirstChild("Likes")
				local MoneyLabel: TextLabel = Frame:FindFirstChild("Money")
				
				CashIcon.Visible = false
				LikeIcon.Visible = false
				
				local workProfile, profileImage = pcall(function()
					return Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
				end)
				
				if workProfile then
					PfpHolder.Image = profileImage
				end
				
				UsernameLabel.Text = `@{Player.Name}`
				DisplayNameLabel.Text = `{Player.DisplayName}`
				MoneyLabel.Text = "$TotalMoney/s"
				LikesLabel.Text = "KeepLikes?"
			end
		end
	end
	
	-- Character References
	local Character: Model = Player.Character or Player.CharacterAdded:Wait()
	local HRP:Part = Character:FindFirstChild("HumanoidRootPart")
	
	-- Teleporting Player to Base
	local PlayerSpawn: Part = PlotModel:WaitForChild("PlayerSpawn")
	HRP.CFrame = PlayerSpawn.CFrame
end

--< Setup Plots
for _, plotModel in ipairs(PlotsFolder:GetChildren()) do
	_PlotsOwner[plotModel] = nil
	task.spawn(ResetPlot, plotModel)
end

--< Module
local module = {
	PlotVisibilityController = PlotVisibilityController
}

function module:GetPlotOwner(PlotModel: Model): Player?
	return _PlotsOwner[PlotModel]
end

function module:GetPlayerPlot(Player: Player): Model?
	return _PlayersPlot[Player]
end

function module:AssignPlot(Player: Player): Model?
	local hasPlot = _PlayersPlot[Player]
	if hasPlot then return hasPlot end

	local selectedPlot: Model? = nil

	-- Try to find an empty plot, retry until one frees up or the player leaves
	while not selectedPlot do
		if not Player.Parent then return nil end

		for _, plotModel in pairs(PlotsFolder:GetChildren()) do
			if not _PlotsOwner[plotModel] then
				_PlotsOwner[plotModel] = Player
				_PlayersPlot[Player] = plotModel
				selectedPlot = plotModel
				break
			end
		end

		if not selectedPlot then
			task.wait(1) -- avoid tight loop while waiting for a free plot
		end
	end

	local PlotValue = Instance.new("ObjectValue")
	PlotValue.Name = "Plot"
	PlotValue.Value = selectedPlot
	PlotValue.Parent = Player

	LoadPlot(selectedPlot, Player)

	return selectedPlot
end

function module:ReleasePlot(Player: Player)
	local plotModel = _PlayersPlot[Player]
	if plotModel then
		_PlotsOwner[plotModel] = nil
		_PlayersPlot[Player] = nil
		task.defer(ResetPlot, plotModel)
	end
end

return module