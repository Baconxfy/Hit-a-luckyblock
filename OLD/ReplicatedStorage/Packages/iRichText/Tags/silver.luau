-- Silver animation - Silver/gray color gradient (like rainbow but silver)
local RunService = game:GetService("RunService")

return {
	Letterwise = true,
	Attributes = { "speed", "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}
		local speed = tonumber(Attributes.speed) or 2
		local time = tonumber(Attributes.time) or 2

		-- Silver color palette
		local silverColors = {
			Color3.fromRGB(192, 192, 192), -- Silver
			Color3.fromRGB(220, 220, 220), -- Light Gray
			Color3.fromRGB(169, 169, 169), -- Dark Gray
			Color3.fromRGB(211, 211, 211), -- Light Silver
			Color3.fromRGB(176, 196, 222), -- Light Steel Blue (silver tint)
		}

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

				-- Calculate position in gradient (0 to 1)
				local gradientPos = (elapsed * speed) % 1

				-- Find the two colors to interpolate between
				local colorIndex = gradientPos * (#silverColors - 1)
				local colorIndex1 = math.floor(colorIndex) + 1
				local colorIndex2 = math.min(colorIndex1 + 1, #silverColors)
				local t = colorIndex - (colorIndex1 - 1)

				local color1 = silverColors[colorIndex1]
				local color2 = silverColors[colorIndex2]

				-- Interpolate between the two colors
				local silverColor = Color3.new(
					color1.R + t * (color2.R - color1.R),
					color1.G + t * (color2.G - color1.G),
					color1.B + t * (color2.B - color1.B)
				)

				local alpha = elapsed / time

				Label.TextColor3 = Color3.new(
					silverColor.R + alpha * (initialColor.R - silverColor.R),
					silverColor.G + alpha * (initialColor.G - silverColor.G),
					silverColor.B + alpha * (initialColor.B - silverColor.B)
				)
			end)
		)

		return Connections
	end,
}
