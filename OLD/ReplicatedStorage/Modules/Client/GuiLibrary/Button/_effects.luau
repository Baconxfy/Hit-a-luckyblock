local TweenService = game:GetService("TweenService")

local Info = TweenInfo.new(.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)


local ClickEffects = {
	
	["Default"] = function(Button:GuiButton, inputObj:InputObject, clickCount:number)
		local UIScale = Button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Button)

		local Tween = TweenService:Create(UIScale, Info, {Scale = .89})
		Tween.Completed:Once(function() 
			Tween:Destroy()

			local oldScale = Button:GetAttribute("oldScale") or 1
			TweenService:Create(UIScale, Info, {Scale = oldScale}):Play()
		end)
		Tween:Play()


	end,
	
}

local HoverEffects = {
	
	["Default"] = function(Button:GuiButton, MouseEnter:boolean, MouseX:number, MouseY:number)
		local UIScale = Button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Button)

		if MouseEnter then
			TweenService:Create(UIScale, Info, {Scale = .95}):Play()
			Button:SetAttribute("oldScale", .95)

		else
			TweenService:Create(UIScale, Info, {Scale = 1}):Play()	
			Button:SetAttribute("oldScale", nil)

		end


	end,
	
}



return {
	Click = ClickEffects,
	Hover = HoverEffects
}
