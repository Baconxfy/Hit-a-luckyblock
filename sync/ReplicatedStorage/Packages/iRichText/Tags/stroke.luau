-- Stroke tag (from Richify) - Text border/stroke
return {
	Letterwise = false,
	Attributes = { "color", "thickness", "transparency", "joins" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Color = Attributes.color
		local Thickness = Attributes.thickness
		local Transparency = Attributes.transparency
		local Joins = Attributes.joins

		local Text = Label.Text
		local strokeTag = "<stroke"

		if Color then
			strokeTag = strokeTag .. ' color="' .. Color .. '"'
		end

		if Thickness then
			strokeTag = strokeTag .. ' thickness="' .. Thickness .. '"'
		end

		if Transparency then
			strokeTag = strokeTag .. ' transparency="' .. Transparency .. '"'
		end

		if Joins then
			strokeTag = strokeTag .. ' joins="' .. Joins .. '"'
		end

		strokeTag = strokeTag .. ">"

		Label.RichText = true
		Label.Text = strokeTag .. Text .. "</stroke>"

		-- Also apply properties directly
		if Thickness then
			Label.TextStrokeTransparency = 0
		elseif not Transparency then
			Label.TextStrokeTransparency = 1
		end
		if Transparency then
			Label.TextStrokeTransparency = tonumber(Transparency) or 0
		end

		return {}
	end,
}
