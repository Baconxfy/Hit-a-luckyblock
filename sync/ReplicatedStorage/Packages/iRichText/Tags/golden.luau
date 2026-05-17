-- Golden animation - Golden/gold color gradient (like rainbow but golden)
local RunService = game:GetService("RunService")

return {
	Letterwise = true,
	Attributes = { "speed", "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}
		local speed = tonumber(Attributes.speed) or 2
		local time = tonumber(Attributes.time) or 2

		-- Golden color palette
		local goldenColors = {
			Color3.fromRGB(255, 215, 0), -- Gold
			Color3.fromRGB(255, 223, 0), -- Bright Gold
			Color3.fromRGB(255, 193, 37), -- Deep Gold
			Color3.fromRGB(218, 165, 32), -- Goldenrod
			Color3.fromRGB(255, 239, 0), -- Light Gold
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
				local colorIndex = gradientPos * (#goldenColors - 1)
				local colorIndex1 = math.floor(colorIndex) + 1
				local colorIndex2 = math.min(colorIndex1 + 1, #goldenColors)
				local t = colorIndex - (colorIndex1 - 1)

				local color1 = goldenColors[colorIndex1]
				local color2 = goldenColors[colorIndex2]

				-- Interpolate between the two colors
				local goldenColor = Color3.new(
					color1.R + t * (color2.R - color1.R),
					color1.G + t * (color2.G - color1.G),
					color1.B + t * (color2.B - color1.B)
				)

				local alpha = elapsed / time

				Label.TextColor3 = Color3.new(
					goldenColor.R + alpha * (initialColor.R - goldenColor.R),
					goldenColor.G + alpha * (initialColor.G - goldenColor.G),
					goldenColor.B + alpha * (initialColor.B - goldenColor.B)
				)
			end)
		)

		return Connections
	end,
}
