---Filters GUI objects in a ScrollingFrame based on a text query.
---Performs a single-pass iteration through all children, checking substring matches
---and setting visibility directly without intermediate data structures.
---@param TextBox TextBox The text input box containing the search query
---@param ScrollingFrame ScrollingFrame The frame containing the items to filter
local function Filter(TextBox: TextBox, ScrollingFrame: ScrollingFrame)
	local Query = TextBox.Text:lower()
	local Items = ScrollingFrame:GetChildren()
	local IsEmptyQuery = Query == ""

	for _, Item in pairs(Items) do
		if Item:IsA("GuiObject") then
			if IsEmptyQuery then
				Item.Visible = true
			else
				local ItemText = Item.Name:lower()
				Item.Visible = ItemText:find(Query, 1, true) ~= nil
			end
		end
	end
end

---Creates a filter connection that automatically filters items when the TextBox text changes.
---@param TextBox TextBox The text input box to monitor for changes
---@param ScrollingFrame ScrollingFrame The frame containing the items to filter
---@return RBXScriptConnection The connection that can be disconnected to stop filtering
return function(TextBox: TextBox, ScrollingFrame: ScrollingFrame): RBXScriptConnection
	local Connection = TextBox:GetPropertyChangedSignal("Text"):Connect(function()
		Filter(TextBox, ScrollingFrame)
	end)
	task.spawn(Filter, TextBox, ScrollingFrame)
	return Connection
end
