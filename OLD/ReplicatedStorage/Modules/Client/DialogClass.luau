--[[

░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

--< Services
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

--< Modules
local GuiController = require(script.Parent:WaitForChild("GuiController"))
local FastSignal = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("FastSignal"))
local iRichText = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("iRichText"))

--< Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

local ButtonsFolder = script.Buttons
local DialogGui = script.DialogGui

--< Constants
local DEFAULT_BUTTON_STYLE = ButtonsFolder.Default
local OPEN_POSITION = DialogGui.MainFrame.Position
local CLOSE_POSITION = UDim2.fromScale(.5, 1.1)
local COMPLETE_MSG_LABEL = UDim2.fromScale(0.9, 0.777)

--< Util Functions

---Creates A Button Instance With The Specified Style, Text, And Click Handler
---@param Style string? The Button Style Name To Use
---@param Text string? The Button Text To Display
---@param Parent Instance The Parent Instance For The Button
---@param OnClick (()->())? The Function To Call When The Button Is Clicked
---@return TextButton The Created Button Instance
function CreateButton(Style: string?, Text: string?, Parent: Instance, OnClick: () -> ()): TextButton
	Style = Style or "Default"
	Text = Text or ""

	local Btn: TextButton = ButtonsFolder:FindFirstChild(Style) or DEFAULT_BUTTON_STYLE
	Btn = Btn:Clone()
	Btn.Text = Text

	if OnClick then
		Btn.Activated:Once(OnClick)
	end

	local UIScale = Btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Btn)
	UIScale.Scale = 0

	Btn.Parent = Parent

	TweenService:Create(UIScale, TweenInfo.new(1, Enum.EasingStyle.Quint), { Scale = 1 }):Play()

	return Btn
end

local module = {}
module.__index = module

--< Types
export type AnswerItemType = {
	Text: string,
	Style: string,
	OnClick: () -> (),
}

export type StageDataType = {
	Main: (NameLabel: TextLabel, MessageLabel: TextLabel) -> (),
	Cleanup: (NameLabel: TextLabel, MessageLabel: TextLabel) -> (),
	Answers: { AnswerItemType },
}

---Creates A New Dialog Controller Instance
---@param UsesRigModels boolean? Whether The Dialog Should Use Rig Models In The Viewport
---@return table The New Dialog Controller Instance
function module.new(UsesRigModels: boolean?, CleanupRigOnClose:boolean?)
	local self = setmetatable({}, module)

	local DialogScreenGui = DialogGui:Clone()
	DialogScreenGui.Enabled = false

	local MainFrame: ImageLabel = DialogScreenGui:FindFirstChild("MainFrame")
	local UiScale = MainFrame:FindFirstChildOfClass("UIScale")
	local NameLabel: TextLabel = MainFrame:FindFirstChild("NameLabel")
	local MessageLabel: TextLabel = MainFrame:FindFirstChild("MessageLabel")
	local AnswersList: ScrollingFrame = MainFrame:FindFirstChild("AnswersList")
	local ViewPort = MainFrame:FindFirstChildWhichIsA("ViewportFrame")

	if not UsesRigModels then
		ViewPort:Destroy()
		MessageLabel.Size = COMPLETE_MSG_LABEL
		ViewPort = nil
	end

	MessageLabel.Text = ""
	NameLabel.Text = ""

	DialogScreenGui.Parent = PlayerGui
	GuiController:SetMainFrame(DialogScreenGui, MainFrame, false, OPEN_POSITION, CLOSE_POSITION)
	
	self._IsOpen = false
	
	self._CleanupRigOnClose = CleanupRigOnClose
	self._UsesRigModels = UsesRigModels
	self._RigModel = nil
	
	self._DialogScreenGui = DialogScreenGui
	self._MainFrame = MainFrame
	self._NameLabel = NameLabel
	self._MessageLabel = MessageLabel
	self._AnswersList = AnswersList
	self._ViewPort = ViewPort
	
	self._StagesList = {}
	self._LastStageCleanup = nil
	self._CreatedButtons = {}

	self.Stage = 0
	self.OnStartDialog = FastSignal.new()
	self.OnEndDialog = FastSignal.new()

	return self
end

---Opens The Dialog And Displays The Specified Stage
---@param StageNumber number? The Stage Number To Display (Defaults To First Stage)
function module:Open(StageNumber: number?)
	if self._IsOpen or GuiController.InDialog then
		return
	end
	GuiController.InDialog = DialogGui
	self._IsOpen = true

	GuiController:HideGuis()
	GuiController:OpenGui(self._DialogScreenGui)
	GuiController:ToggleMainFrame(GuiController:GetMainFrame(self._DialogScreenGui), OPEN_POSITION, CLOSE_POSITION)

	self.OnStartDialog:Fire(self._NameLabel, self._MessageLabel, self._AnswersList, self._ViewPort)
	self:NextStage(StageNumber)
end

---Closes The Dialog And Performs Cleanup Operations
---@param IsDestroying boolean? Whether The Dialog Is Being Destroyed (Skips Cleanup If True)
function module:Close(IsDestroying: boolean)
	if not self._IsOpen or not GuiController.InDialog then
		return
	end
	

	if not IsDestroying then
		self:FullCleanup(self._CleanupRigOnClose, true)
	end

	GuiController:ShowHidenGuis()
	GuiController:ToggleMainFrame()
	task.wait(.1)
	GuiController:OpenGui()

	self.Stage = 0
	self._LastStageCleanup = nil

	GuiController.InDialog = nil
	self._IsOpen = false

	self.OnEndDialog:Fire(self._NameLabel, self._MessageLabel, self._AnswersList, self._ViewPort)
end

---Adds A New Stage To The Dialog Sequence
---@param StageData table The Stage Data Containing Main, Cleanup, And Answers Functions
---@return number The Index Of The Newly Added Stage
function module:AddStage(StageData: {
	Main: (NameLabel: TextLabel, MessageLabel: TextLabel) -> (),
	Cleanup: (NameLabel: TextLabel, MessageLabel: TextLabel) -> (),
	Answers: { AnswerItemType },
	}): number
	table.insert(self._StagesList, StageData)
	return #self._StagesList
end

---Removes A Stage From The Dialog Sequence
---@param StageIndex number The Index Of The Stage To Remove
---@return StageDataType? The Removed Stage Data, Or Nil If Index Is Invalid
function module:RemoveStage(StageIndex: number): StageDataType?
	if (StageIndex < #self._StagesList) or (StageIndex <= 0) then
		return
	end
	return table.remove(self._StagesList, StageIndex)
end

---Gets The Current Stage Number
---@return number The Current Stage Number
function module:CurrentStage(): number
	return self.Stage
end

---Advances To The Next Stage Or Jumps To A Specific Stage
---@param StageNumber number? The Stage Number To Jump To (Defaults To Next Stage)
function module:NextStage(StageNumber: number?)
	local Stage: number = self.Stage
	local StagesList: { StageDataType } = self._StagesList
	local NextStageNumber = StageNumber or Stage + 1

	if #StagesList <= 0 then
		self:Close()
		return
	end

	if NextStageNumber > #StagesList then
		return self:Close()
	elseif NextStageNumber <= 0 then
		NextStageNumber = 1
	end

	self:_CleanupAnswerButtons()

	if self._LastStageCleanup then
		self._LastStageCleanup(self._NameLabel, self._MessageLabel)
		self._LastStageCleanup = nil
	else
		iRichText.Derich(self._MessageLabel)
	end

	local StageData = StagesList[NextStageNumber]
	local Main = StageData.Main
	local Answers = StageData.Answers
	local Cleanup = StageData.Cleanup

	local Work, Result = pcall(Main, self._NameLabel, self._MessageLabel)
	if Work then
		local answersCount = #Answers
		for i = 1, answersCount do
			local answerData = Answers[i]
			local button = CreateButton(answerData.Style, answerData.Text, self._AnswersList, answerData.OnClick)
			table.insert(self._CreatedButtons, button)
		end
	else
		warn(Result)
		self:Close()
		return
	end

	if Cleanup then
		self._LastStageCleanup = Cleanup
	end

	self.Stage = NextStageNumber
end

---Displays A Rig Model In The Dialog Viewport
---@param RigModel Model The Rig Model To Display
---@param Cframe CFrame? The CFrame Position For The Rig Model (Defaults To Origin)
function module:SetRigModel(RigModel: Model, Cframe: CFrame?)
	if not self._ViewPort then
		return
	end
	assert(RigModel, "RigModel is NIL")
	assert(RigModel.PrimaryPart, "RigModel.PrimaryPart is NIL")

	self:CleanupRigModel()

	RigModel.Parent = self._ViewPort
	RigModel:PivotTo(Cframe or CFrame.new(0, 0, 0))
	self._RigModel = RigModel
end

---Cleans Up And Removes The Currently Displayed Rig Model
function module:CleanupRigModel()
	if self._RigModel then
		self._RigModel:Destroy()
		self._RigModel = nil
	end
end

---Performs Full Cleanup Operations Including Rich Text Formatting Removal
---@param CleanupRig boolean? Whether To Also Clean Up The Rig Model (Defaults To False)
---@param CleanupAnswers boolean? Whether To Also Clean Up The Answer Buttons (Defaults To False)
function module:FullCleanup(CleanupRig: boolean?, CleanupAnswers: boolean?)
	if CleanupAnswers then
		self:_CleanupAnswerButtons()
	end
	if CleanupRig then
		self:CleanupRigModel()
	end
	iRichText.Derich(self._NameLabel)
	iRichText.Derich(self._MessageLabel)
end

---Destroys The Dialog Controller And All Associated Resources
function module:Destroy()
	self:Close(true)

	if self.OnStartDialog then
		self.OnStartDialog:Destroy()
	end
	if self.OnEndDialog then
		self.OnEndDialog:Destroy()
	end

	if self._DialogScreenGui then
		self._DialogScreenGui:Destroy()
	end

	self._CreatedButtons = nil
	self._StagesList = nil
	self = nil
end

---Cleans Up All Answer Buttons Created For The Current Stage
function module:_CleanupAnswerButtons()
	local buttonsCount = #self._CreatedButtons
	for i = buttonsCount, 1, -1 do
		local button = self._CreatedButtons[i]
		if button and button.Parent then
			button:Destroy()
		end
		self._CreatedButtons[i] = nil
	end
	self._CreatedButtons = {}
end

return module
