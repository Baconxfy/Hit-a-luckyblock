local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local NextWeatherController = Framework:CreateController("NextWeatherController")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function NextWeatherController:Initialize()
	pcall(function()
		self.ReplicaController = Framework:GetController("ReplicaController")
	end)
end

function NextWeatherController:Start()
	if not self.ReplicaController then
		warn("[NextWeatherController] ReplicaController not found, skipping.")
		return
	end
	
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	local nextWeatherGui = PlayerGui:WaitForChild("HUD"):WaitForChild("RightBuffs"):WaitForChild("NextEvent")
	local timerLabel = nextWeatherGui:WaitForChild("Timer")
	
	local function FormatTime(seconds)
		local m = math.floor(seconds / 60)
		local s = math.floor(seconds % 60)
		return string.format("%02d:%02d", m, s)
	end
	
	local nextWeatherTime = ReplicatedStorage:FindFirstChild("NextWeatherTime")
	local activeWeathers = ReplicatedStorage:FindFirstChild("ActiveWeathers")
	local activeEvents = ReplicatedStorage:FindFirstChild("ActiveEvents")
	
	if not (nextWeatherTime and activeWeathers and activeEvents) then
		warn("[NextWeatherController] Weather instances not found in ReplicatedStorage, disabling weather UI.")
		pcall(function()
			nextWeatherGui.Visible = false
		end)
		return
	end
	
	local function updateVisibilityAndText(timeVal)
		local hasSpecialEvent = false
		for _, event in ipairs(activeEvents:GetChildren()) do
			if event:GetAttribute("IsSpecialEvent") then
				hasSpecialEvent = true
				break
			end
		end
		
		if timeVal > 0 and #activeWeathers:GetChildren() == 0 and not hasSpecialEvent then
			nextWeatherGui.Visible = true
			timerLabel.Text = FormatTime(timeVal)
		else
			nextWeatherGui.Visible = false
		end
	end
	
	task.spawn(function()
		updateVisibilityAndText(nextWeatherTime.Value)
	end)
	
	nextWeatherTime.Changed:Connect(updateVisibilityAndText)
	
	activeWeathers.ChildAdded:Connect(function() updateVisibilityAndText(nextWeatherTime.Value) end)
	activeWeathers.ChildRemoved:Connect(function() updateVisibilityAndText(nextWeatherTime.Value) end)
	
	activeEvents.ChildAdded:Connect(function() updateVisibilityAndText(nextWeatherTime.Value) end)
	activeEvents.ChildRemoved:Connect(function() updateVisibilityAndText(nextWeatherTime.Value) end)
end

return NextWeatherController
