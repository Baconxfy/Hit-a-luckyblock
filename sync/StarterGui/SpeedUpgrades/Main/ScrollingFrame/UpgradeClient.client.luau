local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuyUpgrade = ReplicatedStorage:WaitForChild("BuyUpgrade")
local scrollingFrame = script.Parent

for _, upgradeFrame in ipairs(scrollingFrame:GetChildren()) do
	if upgradeFrame:IsA("GuiObject") then
		local buttonsFrame = upgradeFrame:FindFirstChild("ButtonsFrame")
		if buttonsFrame then
			for _, button in ipairs(buttonsFrame:GetChildren()) do
				if button:IsA("GuiButton") and button.Name ~= "BuyRBX" then
					button.MouseButton1Click:Connect(function()
						print(button.Name .. " was clicked!")
						BuyUpgrade:FireServer(upgradeFrame.Name, button.Name)
					end)
				end
			end
		end
	end
end