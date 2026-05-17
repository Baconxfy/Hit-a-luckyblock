-- Gradient animation - Allows custom colors to be provided
local RunService = game:GetService("RunService")

local function getColorFromString(value: string | Color3): Color3
	if typeof(value) == "Color3" then
		return value
	end

	-- Color shortcuts
	local colorShortcuts = {
		Red = Color3.fromRGB(255, 0, 0),
		Green = Color3.fromRGB(0, 255, 0),
		Blue = Color3.fromRGB(0, 0, 255),
		Yellow = Color3.fromRGB(255, 255, 0),
		White = Color3.fromRGB(255, 255, 255),
		Black = Color3.fromRGB(0, 0, 0),
		Cyan = Color3.fromRGB(0, 255, 255),
		Orange = Color3.fromRGB(255, 165, 0),
		Purple = Color3.fromRGB(128, 0, 128),
		Pink = Color3.fromRGB(255, 192, 203),
	}

	if colorShortcuts[value] then
		return colorShortcuts[value]
	end

	local r, g, b = value:match("(%d+),(%d+),(%d+)")
	if r and g and b then
		return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
	end

	-- Try as hex
	local hexMatch = value:match("^#(%x%x)(%x%x)(%x%x)$")
	if hexMatch then
		return Color3.fromHex(value)
	end

	return Color3.new(1, 1, 1) -- Default white
end

return {
	Letterwise = true,
	Attributes = { "colors", "speed", "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}
		local speed = tonumber(Attributes.speed) or 2
		local time = tonumber(Attributes.time) or 2
		local colorsString = Attributes.colors or ""

		-- Parse colors from string (format: "#FF0000,#00FF00,#0000FF" or "Red,Green,Blue")
		local colors = {}
		if colorsString ~= "" then
			for colorStr in string.gmatch(colorsString, "([^,]+)") do
				colorStr = colorStr:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace
				local color = getColorFromString(colorStr)
				table.insert(colors, color)
			end
		end

		-- Default gradient if no colors provided
		if #colors == 0 then
			colors = {
				Color3.fromRGB(255, 0, 0), -- Red
				Color3.fromRGB(255, 165, 0), -- Orange
				Color3.fromRGB(255, 255, 0), -- Yellow
				Color3.fromRGB(0, 255, 0), -- Green
				Color3.fromRGB(0, 0, 255), -- Blue
				Color3.fromRGB(75, 0, 130), -- Indigo
				Color3.fromRGB(238, 130, 238), -- Violet
			}
		end

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
				local colorIndex = gradientPos * (#colors - 1)
				local colorIndex1 = math.floor(colorIndex) + 1
				local colorIndex2 = math.min(colorIndex1 + 1, #colors)
				local t = colorIndex - (colorIndex1 - 1)

				local color1 = colors[colorIndex1]
				local color2 = colors[colorIndex2]

				-- Interpolate between the two colors
				local gradientColor = Color3.new(
					color1.R + t * (color2.R - color1.R),
					color1.G + t * (color2.G - color1.G),
					color1.B + t * (color2.B - color1.B)
				)

				local alpha = elapsed / time

				Label.TextColor3 = Color3.new(
					gradientColor.R + alpha * (initialColor.R - gradientColor.R),
					gradientColor.G + alpha * (initialColor.G - gradientColor.G),
					gradientColor.B + alpha * (initialColor.B - gradientColor.B)
				)
			end)
		)

		return Connections
	end,
}
