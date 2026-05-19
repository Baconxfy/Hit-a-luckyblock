local menu = script.Parent
local closeBtn = menu:WaitForChild("Main"):WaitForChild("Top"):WaitForChild("Close")

closeBtn.MouseButton1Click:Connect(function()
	menu.Visible = false
end)