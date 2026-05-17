-- Underline tag (from Richify)
return {
	Letterwise = false,
	Attributes = {},
	Apply = function(Label: TextLabel, _: { [string]: string }): { RBXScriptConnection }
		Label.RichText = true
		Label.Text = "<u>" .. Label.Text .. "</u>"
		return {}
	end,
}
