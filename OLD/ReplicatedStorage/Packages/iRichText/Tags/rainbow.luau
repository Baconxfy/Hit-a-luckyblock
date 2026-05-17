-- Rainbow animation (from RichTextPlus)
local RunService = game:GetService("RunService")

return {
	Letterwise = true,
	Attributes = { "speed", "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}
		local speed = tonumber(Attributes.speed) or 3
		local time = tonumber(Attributes.time) or 2

		local initialColor = Label.TextColor3
		local elapsed = 0

		table.insert(
			Connections,
			RunService.RenderStepped:Connect(function()
				elapsed += RunService.RenderStepped:Wait()
				if elapsed > time then
					Label.TextColor3 = initialColor
					return
				end

				local hue = (elapsed * speed) % 1
				local rainbowColor = Color3.fromHSV(hue, 1, 1)
				local alpha = elapsed / time

				Label.TextColor3 = Color3.new(
					rainbowColor.R + alpha * (initialColor.R - rainbowColor.R),
					rainbowColor.G + alpha * (initialColor.G - rainbowColor.G),
					rainbowColor.B + alpha * (initialColor.B - rainbowColor.B)
				)
			end)
		)

		return Connections
	end,
}
