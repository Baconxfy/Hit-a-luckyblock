-- Bounce animation: text becomes smaller and returns to normal size
local TweenService = game:GetService("TweenService")

return {
	Letterwise = false,
	Attributes = { "time", "smallSize", "speed" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local time = tonumber(Attributes.time) or 0.5
		local smallSizeFactor = tonumber(Attributes.smallSize) or 0.8
		local speed = tonumber(Attributes.speed) or 1

		local initialSize = Label.TextSize
		local smallSize = initialSize * smallSizeFactor

		-- Tween to small size
		local shrinkTween = TweenService:Create(
			Label,
			TweenInfo.new(time / 2 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextSize = smallSize }
		)

		-- Tween back to normal size
		local growTween = TweenService:Create(
			Label,
			TweenInfo.new(time / 2 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextSize = initialSize }
		)

		shrinkTween:Play()
		shrinkTween.Completed:Connect(function()
			growTween:Play()
		end)

		return {}
	end,
}
