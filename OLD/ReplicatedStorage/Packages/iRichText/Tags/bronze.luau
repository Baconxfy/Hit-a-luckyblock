-- Bronze animation - Bronze/brown color gradient (like rainbow but bronze)
local RunService = game:GetService("RunService")

return {
	Letterwise = true,
	Attributes = { "speed", "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}
		local speed = tonumber(Attributes.speed) or 2
		local time = tonumber(Attributes.time) or 2

		-- Bronze color palette
		local bronzeColors = {
			Color3.fromRGB(205, 127, 50), -- Bronze
			Color3.fromRGB(184, 115, 51), -- Dark Bronze
			Color3.fromRGB(218, 145, 0), -- Bright Bronze
			Color3.fromRGB(160, 82, 45), -- Saddle Brown
			Color3.fromRGB(210, 180, 140), -- Tan
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
				local colorIndex = gradientPos * (#bronzeColors - 1)
				local colorIndex1 = math.floor(colorIndex) + 1
				local colorIndex2 = math.min(colorIndex1 + 1, #bronzeColors)
				local t = colorIndex - (colorIndex1 - 1)

				local color1 = bronzeColors[colorIndex1]
				local color2 = bronzeColors[colorIndex2]

				-- Interpolate between the two colors
				local bronzeColor = Color3.new(
					color1.R + t * (color2.R - color1.R),
					color1.G + t * (color2.G - color1.G),
					color1.B + t * (color2.B - color1.B)
				)

				local alpha = elapsed / time

				Label.TextColor3 = Color3.new(
					bronzeColor.R + alpha * (initialColor.R - bronzeColor.R),
					bronzeColor.G + alpha * (initialColor.G - bronzeColor.G),
					bronzeColor.B + alpha * (initialColor.B - bronzeColor.B)
				)
			end)
		)

		return Connections
	end,
}
