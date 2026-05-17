local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menu = require(ReplicatedStorage:WaitForChild("Shared").Components:FindFirstChild("Menu", true) :: ModuleScript)
local Numbers = require(ReplicatedStorage:WaitForChild("Shared").Utils:WaitForChild("Numbers"))

local MicrowaveShopClient = Menu:Extend("MicrowaveShopClient")

local function formatMoney(value: number): string
	return "$" .. Numbers.Format.abbreviate(math.max(0, tonumber(value) or 0), 2)
end

local function findTextButton(root: Instance?, name: string): TextButton?
	local instance = root and root:FindFirstChild(name, true)
	return if instance and instance:IsA("TextButton") then instance else nil
end

local function findRowButton(root: Instance?): GuiButton?
	local namedButton = findTextButton(root, "Rebirth")
	if namedButton then
		return namedButton
	end

	local instance = root and root:FindFirstChildWhichIsA("GuiButton", true)
	return if instance and instance:IsA("GuiButton") then instance else nil
end

local function getHighestZIndex(root: Instance): number
	local highest = 1
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			highest = math.max(highest, descendant.ZIndex)
		end
	end
	return highest
end

local function ensureRowButton(row: Frame): GuiButton
	local existing = findRowButton(row)
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Name = "ShopButton"
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = getHighestZIndex(row) + 1
	button.Parent = row
	return button
end

local function setFirstTextLabel(root: Instance, text: string, excludedAncestor: Instance?)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("TextLabel") and (not excludedAncestor or not descendant:IsDescendantOf(excludedAncestor)) then
			descendant.Text = text
			return
		end
	end
end

local function setButtonText(button: GuiButton?, text: string)
	if not button then
		return
	end

	if button:IsA("TextButton") then
		button.Text = ""
	end
	local label = button:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = text
	end
end

function MicrowaveShopClient:GetMenuFrameName(): string
	local microwaveConfig = self.Framework.Config and self.Framework.Config.Microwave
	return (microwaveConfig and microwaveConfig.ShopFrameName) or "MicrowaveShopFrame"
end

function MicrowaveShopClient:Create(screenGui: ScreenGui)
	self.ContentHolder = self.Frame and self.Frame:FindFirstChild("ContentHolder", true)
	self.MicrowaveService = self.Framework:GetService("MicrowaveService")
	self._rowButtons = {}
	self._requestActive = false

	self:BindRows()
	self:Refresh()
end

function MicrowaveShopClient:BindRows()
	if not self.ContentHolder then
		return
	end

	for _, row in ipairs(self.ContentHolder:GetChildren()) do
		if row:IsA("Frame") then
			local button = ensureRowButton(row)
			local buttonComponent = self.Framework.Components.Button:new(button)
			buttonComponent:SetOnClick(function()
				self:BuyOrEquip(row.Name)
			end)
			self:AddChild(buttonComponent)
			self._rowButtons[row.Name] = {
				Frame = row,
				Button = button,
			}
		end
	end
end

function MicrowaveShopClient:RefreshBeforeOpen()
	self:Refresh()
end

function MicrowaveShopClient:Refresh()
	local ok, state = pcall(function()
		return self.MicrowaveService:GetShopState()
	end)

	if ok and type(state) == "table" and state.Ok == true then
		self:ApplyState(state)
	end
end

function MicrowaveShopClient:ApplyState(state)
	local items = type(state.Items) == "table" and state.Items or {}
	local seen = {}

	for _, item in ipairs(items) do
		local rowData = self._rowButtons[item.Id]
		if rowData then
			seen[item.Id] = true
			rowData.Frame.Visible = true
			rowData.Frame.LayoutOrder = tonumber(item.Order) or rowData.Frame.LayoutOrder
			setFirstTextLabel(rowData.Frame, tostring(item.DisplayName or item.Id), rowData.Button)

			if item.Equipped then
				if item.Id == state.DefaultMicrowaveId then
					setButtonText(rowData.Button, "Equipped")
				else
					setButtonText(rowData.Button, "Unequip")
				end
			elseif item.Owned then
				setButtonText(rowData.Button, "Equip")
			else
				setButtonText(rowData.Button, formatMoney(tonumber(item.Price) or 0))
			end
		end
	end

	for id, rowData in pairs(self._rowButtons) do
		if not seen[id] then
			rowData.Frame.Visible = false
		end
	end
end

function MicrowaveShopClient:BuyOrEquip(microwaveId: string)
	if self._requestActive then
		return
	end

	self._requestActive = true
	local ok, state = pcall(function()
		return self.MicrowaveService:BuyOrEquipMicrowave(microwaveId)
	end)
	self._requestActive = false

	if ok and type(state) == "table" then
		self:ApplyState(state)
	else
		warn(("[MicrowaveShopClient] Buy/equip failed for %s: %s"):format(tostring(microwaveId), tostring(state)))
		self:Refresh()
	end
end

return MicrowaveShopClient
