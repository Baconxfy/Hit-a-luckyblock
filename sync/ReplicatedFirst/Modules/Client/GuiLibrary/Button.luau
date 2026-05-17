--< Modules
local GuiController = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiController"))

--< Variables
local _sounds = script._sounds
local _effects = require(script._effects)

--< Constants
local DEFAULT_CLICK_SOUND = _sounds.Click
local DEFAULT_HOVER_SOUND = _sounds.Hover

local DEFAULT_CLICK_EFFECT = _effects.Click.Default
local DEFAULT_HOVER_EFFECT = _effects.Hover.Default

local module = {}

function module.OnClick(Button :GuiButton, Callback:(inputObj:InputObject, clickCount:number)->()?, Sound:boolean|string?, Effect:boolean|string?) :RBXScriptConnection
	
	if Effect then
		if typeof(Effect) == "string" then
			Effect = _effects.Click[Effect]
		else
			Effect = DEFAULT_CLICK_EFFECT
		end
	end
	
	if Sound then
		if typeof(Sound) == "string" then
			Sound = _sounds:FindFirstChild(Sound)
		else
			Sound = DEFAULT_CLICK_SOUND
		end
	end
	
	return Button.Activated:Connect(function(...) 
		
		if Effect then
			task.spawn(Effect, Button, ...)
		end

		if Sound then
			Sound:Play()
		end
		
		if Callback then
			Callback(...)
		end
		
	end)
	
end

function module.OnClickToggleGui(Button :GuiButton, Gui:ScreenGui?, Callback:(inputObj:InputObject, clickCount:number)->()?, Sound:boolean|string?, Effect:boolean|string?) :RBXScriptConnection
	
	if Effect then
		if typeof(Effect) == "string" then
			Effect = _effects.Click[Effect]
		else
			Effect = DEFAULT_CLICK_EFFECT
		end
	end

	if Sound then
		if typeof(Sound) == "string" then
			Sound = _sounds:FindFirstChild(Sound)
		else
			Sound = DEFAULT_CLICK_SOUND
		end
	end

	return Button.Activated:Connect(function(...) 

		if Effect then
			task.spawn(Effect, Button, ...)
		end

		if Sound then
			Sound:Play()
		end
		
		GuiController:OpenGui(Gui)
		
		if Callback then
			Callback(...)
		end

	end)
	
end

function module.OnClickToggleFrame(Button :GuiButton, Frame:GuiObject?, Callback:(inputObj:InputObject, clickCount:number)->()?, Sound:boolean|string?, Effect:boolean|string?) :RBXScriptConnection

	if Effect then
		if typeof(Effect) == "string" then
			Effect = _effects.Click[Effect]
		else
			Effect = DEFAULT_CLICK_EFFECT
		end
	end

	if Sound then
		if typeof(Sound) == "string" then
			Sound = _sounds:FindFirstChild(Sound)
		else
			Sound = DEFAULT_CLICK_SOUND
		end
	end

	return Button.Activated:Connect(function(...) 

		if Effect then
			task.spawn(Effect, Button, ...)
		end
		
		if Sound then
			Sound:Play()
		end

		GuiController:ToggleMainFrame(Frame)

		if Callback then
			Callback(...)
		end

	end)

end

function module.Hover(Button :GuiButton, OnEnter:(x:number,y:number)->(), OnLeave:(x:number,y:number)->(), Sound:boolean|string?, Effect:boolean|string? ) :{ Enter:RBXScriptConnection, Leave:RBXScriptConnection, DisconnectAll:()->() }
	
	if Effect then
		if typeof(Effect) == "string" then
			Effect = _effects.Hover[Effect]
		else
			Effect = DEFAULT_HOVER_EFFECT
		end
	end

	if Sound then
		if typeof(Sound) == "string" then
			Sound = _sounds:FindFirstChild(Sound)
		else
			Sound = DEFAULT_HOVER_SOUND
		end
	end

	local Enter = Button.MouseEnter:Connect(function(...) 
		
		if Effect then
			task.spawn(Effect, Button, true, ...)
		end
		
		if Sound then
			Sound:Play()
		end
		
		if OnEnter then
			OnEnter(...)
		end
		
	end)
	
	local Leave = Button.MouseLeave:Connect(function(...) 
		
		if Effect then
			task.spawn(Effect, Button, false, ...)
		end
		
		if OnLeave then
			OnLeave(...)
		end
		
	end)
	
	return {
		Enter = Enter,
		Leave = Leave,
		DisconnectAll = function()
			Enter:Disconnect()
			Leave:Disconnect()
			Enter = nil
			Leave = nil
		end,
	}
	
end

return module
