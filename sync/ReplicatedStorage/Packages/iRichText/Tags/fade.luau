-- Fade animation (from lipetos_richtext and zserxue_richtext)
local TweenService = game:GetService("TweenService")

return {
	Letterwise = true,
	Attributes = { "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local time = tonumber(Attributes.time) or 0.5
		Label.TextTransparency = 1

		TweenService
			:Create(
				Label,
				TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ TextTransparency = 0 }
			)
			:Play()

		return {}
	end,
}
