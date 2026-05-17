--[[

░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

--!strict

--[[
	iRichText Module
	
	A comprehensive rich text formatting system for Roblox that supports custom tags,
	animations, styling, and formatting. Allows you to create visually rich text with
	formatting tags, animations, custom fonts, colors, and more.
	
	@module iRichText
]]

local iRichText = {}

local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Stack = require(script.Parent.Stack)

--[[
	Tag Type
	
	Represents a parsed HTML-like tag from the rich text input.
	
	@field Type "Tag" Always "Tag" for tag tokens
	@field Name string The name of the tag (e.g., "font", "b", "rainbow")
	@field Opening boolean Whether this is an opening tag (<tag>) or closing tag (</tag>)
	@field Content { [string]: string } A dictionary of attribute name-value pairs
]]
type Tag = {
	Type: "Tag",
	Name: string,
	Opening: boolean,
	Content: { [string]: string },
}

--[[
	Text Type
	
	Represents a plain text token from the rich text input.
	
	@field Type "Text" Always "Text" for text tokens
	@field Content string The actual text content
]]
type Text = {
	Type: "Text",
	Content: string,
}

--[[
	Properties Type
	
	Configuration options for enriching text with animations and effects.
	
	@field DerichDelay number? Optional delay in seconds for the derich animation fade-out
	@field AfterEnrichDelay number? Optional delay in seconds to wait after enriching before deriching
	@field TypewriteTime number? Optional time in seconds between characters for typewriter effect (default: 0.05)
	@field Sound Sound? Optional sound to play during typewriter effect
]]
export type Properties = {
	DerichDelay: number?,
	AfterEnrichDelay: number?,
	TypewriteTime: number?,
	Sound: Sound?,
}

--[[
	TextContainer Type
	
	Union type of Roblox UI elements that can display rich text.
	
	@type TextContainer TextLabel | TextBox | TextButton
]]
export type TextContainer = TextLabel | TextBox | TextButton

--[[
	ContainerProperties Type
	
	Stores all text-related properties from a TextContainer for use in rich text rendering.
]]
type ContainerProperties = {
	FontFace: Font,
	Font: Enum.Font,
	FontSize: number,
	LineHeight: number,
	TextColor3: Color3,
	TextStrokeColor3: Color3,
	TextStrokeTransparency: number,
	TextTransparency: number,
	TextXAlignment: Enum.TextXAlignment,
	TextYAlignment: Enum.TextYAlignment,
}

local Connections: { [Folder]: { RBXScriptConnection } } = {}

local Modules = {}
for _, Child in script.Tags:GetChildren() do
	if not Child:IsA("ModuleScript") then
		continue
	end
	Modules[Child.Name] = require(Child)
end

--[[
	ColorShortcuts
	
	A dictionary of named color shortcuts that can be used in tags.
	These color names can be used directly in color attributes.
	
	Available colors: Red, Green, Blue, Yellow, White, Black, Cyan, Orange, Purple, Pink
	
	@type { [string]: Color3 }
	
	@example
		-- Use in a font tag:
		<font color="Red">Hello</font>
]]
iRichText.ColorShortcuts = {
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

--[[
	ImageShortcuts
	
	A dictionary of named image shortcuts that can be used in image tags.
	These image names map to Roblox asset IDs.
	
	Available images: Thinking, Happy, Sad, Eggplant, Despicable
	
	@type { [string]: number }
]]
iRichText.ImageShortcuts = {
	Thinking = 639588687,
	Happy = 639588886,
	Sad = 639589059,
	Eggplant = 639587487,
	Despicable = 639587699,
}

iRichText.RichTextCointainerName = "<RichTextContainer>"

--[[
	Reads and parses a single HTML-like tag string into a Tag object.
	
	Extracts the tag name, whether it's opening or closing, and all attributes.
	
	@param Tag string The raw tag string (e.g., '<font color="red">' or '</font>')
	@return Tag? The parsed tag object, or nil if parsing fails
	@warning Warns if the tag format is invalid
]]
function iRichText.ReadTag(Tag: string): Tag?
	-- Remove outer angle brackets
	local tagContent = string.sub(Tag, 2, -2)

	-- Extract name chunk (tag name with optional slash)
	local nameStart, nameEnd = string.find(tagContent, "^%s*/?%a+%s*")
	if not nameStart then
		warn(`Parsed Tag ({Tag}) could not be read.`)
		return
	end

	local NameChunk = string.sub(tagContent, nameStart, nameEnd)
	local Opening = string.find(NameChunk, "/") == nil
	local Name = string.gsub(NameChunk, "[%s/]", "")

	local AttributesChunk = string.sub(tagContent, nameEnd + 1, -1)
	local Content = {}

	-- Parse attributes more efficiently
	for key, value in string.gmatch(AttributesChunk, '(%a+)%s*=%s*"(.-)"') do
		Content[key] = value
	end

	return {
		Type = "Tag",
		Name = Name,
		Opening = Opening,
		Content = Content,
	}
end

--[[
	Parses a rich text string into a sequence of Tag and Text tokens.
	
	Breaks down the input string into alternating tags and text segments,
	handling nested and sequential tags properly.
	
	@param Input string The rich text string containing tags (e.g., 'Hello <b>world</b>!')
	@return { Tag | Text } An array of Tag and Text tokens in order
]]
function iRichText.ParseText(Input: string): { Tag | Text }
	local Tokens: { Tag | Text } = {}
	local tokenCount = 0
	local inputPos = 1
	local inputLen = #Input

	while inputPos <= inputLen do
		local TagStart, TagEnd = string.find(Input, "<.->", inputPos)

		if TagStart then
			-- Text before tag
			if TagStart > inputPos then
				tokenCount += 1
				Tokens[tokenCount] = {
					Type = "Text",
					Content = string.sub(Input, inputPos, TagStart - 1),
				}
			end

			-- Tag itself
			local Chunk = string.sub(Input, TagStart, TagEnd)
			tokenCount += 1
			Tokens[tokenCount] = iRichText.ReadTag(Chunk) or {
				Type = "Text",
				Content = Chunk,
			}

			inputPos = TagEnd + 1
		else
			-- Remaining text
			if inputPos <= inputLen then
				tokenCount += 1
				Tokens[tokenCount] = {
					Type = "Text",
					Content = string.sub(Input, inputPos, -1),
				}
			end
			break
		end
	end

	return Tokens
end

--[[
	Validates that all tags in the token sequence are properly nested and valid.
	
	Checks for:
	- Balanced opening and closing tags
	- Valid tag names (must exist in the Tags folder)
	- Valid attributes (must be defined in the tag's Attributes array)
	- Proper tag nesting (no overlapping tags)
	
	@param Tokens { Tag | Text } The array of tokens to validate
	@return boolean True if all tags are valid and properly nested, false otherwise
	@warning Warns about invalid tags, attributes, and nesting issues
]]
function iRichText.ValidateTokens(Tokens: { Tag | Text }): boolean
	local Tags = Stack.new()

	for i = 1, #Tokens do
		local Token = Tokens[i]
		if Token.Type ~= "Tag" then
			continue
		end

		local tokenName = Token.Name
		if tokenName == "br" or tokenName == "img" then
			continue
		end

		local Module = Modules[tokenName]
		if not Module then
			warn(`Invalid token ({tokenName}), tag does not exist.`)
			return false
		end

		-- Create attribute set for O(1) lookup instead of O(n) table.find
		local validAttributes: { [string]: boolean } = {}
		for _, attr in ipairs(Module.Attributes) do
			validAttributes[attr] = true
		end

		for Attribute in pairs(Token.Content) do
			if not validAttributes[Attribute] then
				warn(`Invalid attribute ({Attribute}) defined for tag ({tokenName}).`)
				return false
			end
		end

		if Token.Opening then
			Tags:Push(tokenName)
		else
			-- Check if closing tag has attributes (warning only)
			for _ in pairs(Token.Content) do
				warn(
					`Warning, attributes defined for closing tag ({tokenName}), please define attributes in opening tag instead.`
				)
				break
			end

			if Tags:Empty() then
				warn(`Unbalanced Tags. Could not close <{tokenName}>.`)
				return false
			end

			local Top = Tags:Pop()
			if Top ~= tokenName then
				warn(`Invalid nesting of Tags. Expected </{Top}>, got </{tokenName}>.`)
				return false
			end
		end
	end

	if not Tags:Empty() then
		for _, Tag in Tags do
			warn(`Missing closing tag </{Tag}>.`)
		end
		return false
	end

	return true
end

local function getColorFromString(value: string | Color3): Color3
	if typeof(value) == "Color3" then
		return value
	end

	if iRichText.ColorShortcuts[value] then
		return iRichText.ColorShortcuts[value]
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

--[[
	Builds a TextLabel with applied formatting and animations based on the current tag state.
	
	Creates a Frame containing a TextLabel with all properties from the container,
	then applies all active tag effects from the state stack.
	
	@param Text string The text content for the label
	@param RichTextContainer Folder The container folder holding all rich text elements
	@param Properties ContainerProperties The text properties from the original TextContainer
	@param State Stack.Stack The current stack of active tags
]]
local function BuildLabel(
	Text: string,
	RichTextContainer: Folder,
	Properties: ContainerProperties,
	State: Stack.Stack,
	LayoutOrder: number
)
	local Frame = Instance.new("Frame")
	Frame.BackgroundTransparency = 1

	local Label = Instance.new("TextLabel")
	Label.BackgroundTransparency = 1
	Label.Text = Text
	Label.LayoutOrder = LayoutOrder

	-- Use properties directly
	local FontSize = Properties.FontSize
	if FontSize <= 0 then
		FontSize = 14 -- Default fallback
	end

	-- Apply all text properties from the container
	Label.FontFace = Properties.FontFace
	Label.LineHeight = Properties.LineHeight
	Label.TextColor3 = Properties.TextColor3
	Label.TextSize = FontSize
	Label.TextScaled = false -- Always use explicit TextSize for individual labels
	Label.TextStrokeColor3 = Properties.TextStrokeColor3
	Label.TextStrokeTransparency = Properties.TextStrokeTransparency
	Label.TextTransparency = Properties.TextTransparency
	Label.TextXAlignment = Properties.TextXAlignment
	Label.TextYAlignment = Properties.TextYAlignment

	local Width = TextService:GetTextSize(Text, FontSize, Properties.Font, Vector2.one * math.huge).X

	Frame.Size = UDim2.fromOffset(Width, FontSize)
	Label.Size = UDim2.fromScale(1, 1)
	Label.Parent = Frame
	Frame.Parent = RichTextContainer

	-- Build attributes map more efficiently
	local Attributes: { [string]: { [string]: string } } = {}
	for _, Tag in State do
		local tagName = Tag.Name
		local attrTable = Attributes[tagName]
		if not attrTable then
			attrTable = {}
			Attributes[tagName] = attrTable
		end

		for Key, Value in pairs(Tag.Content) do
			attrTable[Key] = Value
		end
	end

	-- Apply tag effects
	for tagName, attrTable in pairs(Attributes) do
		local Module = Modules[tagName]
		if Module and Module.Apply then
			local connections = Connections[RichTextContainer]
			for _, Connection in Module.Apply(Label, attrTable) do
				connections[#connections + 1] = Connection
			end
		end
	end
end

--[[
	Enriches a TextContainer with formatted and animated rich text.
	
	This is the main function for applying rich text formatting. It:
	1. Parses the input text for tags
	2. Validates all tags and their attributes
	3. Creates individual TextLabels for each text segment
	4. Applies formatting and animations based on tags
	5. Handles typewriter effects if letterwise tags are active
	
	The original TextContainer's Text property is set to a single space,
	and all rich text is rendered as child Frames containing TextLabels.
	
	@param TextContainer TextContainer The TextLabel, TextBox, or TextButton to enrich
	@param Text string? Optional text to use instead of TextContainer.Text
	@param Properties Properties? Optional configuration for animations and timing
	@warning Returns early if tag validation fails
]]
function iRichText.EnrichAsync(TextContainer: TextContainer, Text: string?, Properties: Properties?): ()
	local RichTextContainer = Instance.new("Folder")
	RichTextContainer.Name = iRichText.RichTextCointainerName
	RichTextContainer.Parent = TextContainer

	Connections[RichTextContainer] = {}

	TextContainer = TextContainer :: TextLabel
	Text = Text or TextContainer.Text

	-- IMPORTANT: Store all properties BEFORE changing the text to avoid size issues
	local textSize: number
	local textScaled = TextContainer.TextScaled
	if textScaled then
		-- When TextScaled is true, use a fixed size instead of calculating
		-- Individual labels will have TextScaled = false, so we use explicit TextSize
		textSize = 100
	else
		textSize = TextContainer.TextSize
	end

	-- Create properties table with all text properties
	local containerProperties: ContainerProperties = {
		FontFace = TextContainer.FontFace,
		Font = TextContainer.Font,
		FontSize = textSize,
		LineHeight = TextContainer.LineHeight,
		TextColor3 = TextContainer.TextColor3,
		TextStrokeColor3 = TextContainer.TextStrokeColor3,
		TextStrokeTransparency = TextContainer.TextStrokeTransparency,
		TextTransparency = TextContainer.TextTransparency,
		TextXAlignment = TextContainer.TextXAlignment,
		TextYAlignment = TextContainer.TextYAlignment,
	}

	-- Convert TextXAlignment to HorizontalAlignment for UIListLayout
	local horizontalAlignment: Enum.HorizontalAlignment
	if TextContainer.TextXAlignment == Enum.TextXAlignment.Left then
		horizontalAlignment = Enum.HorizontalAlignment.Left
	elseif TextContainer.TextXAlignment == Enum.TextXAlignment.Right then
		horizontalAlignment = Enum.HorizontalAlignment.Right
	else
		horizontalAlignment = Enum.HorizontalAlignment.Center
	end

	-- Convert TextYAlignment to VerticalAlignment for UIListLayout
	local verticalAlignment: Enum.VerticalAlignment
	if TextContainer.TextYAlignment == Enum.TextYAlignment.Top then
		verticalAlignment = Enum.VerticalAlignment.Top
	elseif TextContainer.TextYAlignment == Enum.TextYAlignment.Bottom then
		verticalAlignment = Enum.VerticalAlignment.Bottom
	else
		verticalAlignment = Enum.VerticalAlignment.Center
	end

	local Layout = Instance.new("UIListLayout")
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.VerticalAlignment = verticalAlignment
	Layout.HorizontalAlignment = horizontalAlignment
	Layout.ItemLineAlignment = Enum.ItemLineAlignment.End
	Layout.Wraps = TextContainer.TextWrapped
	Layout.Parent = RichTextContainer

	TextContainer.Text = " "

	local Tokens = iRichText.ParseText(Text)
	if not iRichText.ValidateTokens(Tokens) then
		return
	end

	local LetterwiseCount = 0
	local State = Stack.new()
	local TypewriteTime = if Properties and Properties.TypewriteTime then Properties.TypewriteTime else 0.05
	local layoutOrder = 0

	for i = 1, #Tokens do
		local Token = Tokens[i]
		if Token.Type == "Tag" then
			local tokenName = Token.Name
			if tokenName == "br" then
				local Linebreak = Instance.new("Frame")
				Linebreak.BackgroundTransparency = 1
				Linebreak.Size = UDim2.fromScale(1, 0)
				Linebreak.Parent = RichTextContainer
				layoutOrder += 1
				continue
			end

			local Module = Modules[tokenName]
			if Token.Opening then
				State:Push(Token)
				if Module and Module.Letterwise then
					LetterwiseCount += 1
				end
			else
				State:Pop()
				if Module and Module.Letterwise then
					LetterwiseCount -= 1
				end
			end
		else
			local content = Token.Content
			if LetterwiseCount == 0 then
				layoutOrder += 1
				BuildLabel(content, RichTextContainer, containerProperties, State, layoutOrder)
			else
				-- Iterate over string more efficiently than string.split
				local typewriteSound = if Properties and Properties.Sound then Properties.Sound else nil
				for charPos = 1, #content do
					local char = string.sub(content, charPos, charPos)
					layoutOrder += 1
					BuildLabel(char, RichTextContainer, containerProperties, State, layoutOrder)

					-- Play typewrite sound if provided and character is not whitespace
					if typewriteSound and not string.match(char, "^%s$") then
						local soundClone = typewriteSound:Clone()
						soundClone.Parent = TextContainer
						soundClone:Play()
						soundClone.Ended:Connect(function()
							soundClone:Destroy()
						end)
					end

					task.wait(TypewriteTime)
				end
			end
		end
	end
end

--[[
	Removes rich text formatting from a TextContainer.
	
	Disconnects all animation connections and destroys the rich text container.
	If Delay is provided, text will fade out over the specified duration before removal.
	
	@param TextContainer TextContainer The TextContainer that was previously enriched
	@param Delay number? Optional fade-out duration in seconds. If nil, removes immediately
]]
function iRichText.Derich(TextContainer: TextContainer, Delay: number?): ()
	local RichTextContainer: Instance? = TextContainer:FindFirstChild(iRichText.RichTextCointainerName)
	if not RichTextContainer or not RichTextContainer:IsA("Folder") then
		return
	end

	TextContainer = TextContainer :: TextLabel

	if not RichTextContainer then
		return
	end

	if Delay then
		for _, Frame in RichTextContainer:GetChildren() do
			if Frame.ClassName ~= "Frame" then
				continue
			end

			for _, TextLabel in Frame:GetChildren() do
				if TextLabel.ClassName ~= "TextLabel" then
					continue
				end

				TextLabel = TextLabel :: TextLabel
				if TextLabel.TextTransparency == 1 then
					continue
				end

				TweenService:Create(
					TextLabel,
					TweenInfo.new(Delay, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ TextTransparency = 1 }
				):Play()
			end
		end

		task.wait(Delay)

		for _, Connection in Connections[RichTextContainer] do
			Connection:Disconnect()
		end

		table.clear(Connections[RichTextContainer])

		RichTextContainer:Destroy()
	else
		for _, Connection in Connections[RichTextContainer] do
			Connection:Disconnect()
		end

		table.clear(Connections[RichTextContainer])

		RichTextContainer:Destroy()
	end
end

--[[
	Enriches a TextContainer and then automatically derichs it after a delay.
	
	Convenience function that combines EnrichAsync and Derich with default timing.
	
	Default timing:
	- AfterEnrichDelay: 1 second (wait before starting fade-out)
	- DerichDelay: 0.3 seconds (fade-out duration)
	- TypewriteTime: 0.05 seconds (character delay)
	
	These defaults can be overridden in the Properties parameter.
	
	@param TextContainer TextContainer The TextContainer to enrich and then derich
	@param Text string? Optional text to use instead of TextContainer.Text
	@param Properties Properties? Optional configuration for timing and animations
]]
function iRichText.EnrichAndDerichAsync(TextContainer: TextContainer, Text: string?, Properties: Properties?)
	setmetatable(Properties or {}, {
		__index = {
			DerichDelay = 0.3,
			AfterEnrichDelay = 1,
			TypewriteTime = 0.05,
		},
	})

	iRichText.EnrichAsync(TextContainer, Text, Properties)

	task.wait((Properties or {}).AfterEnrichDelay or 1)

	if not TextContainer then
		return
	end

	iRichText.Derich(TextContainer, (Properties or {}).DerichDelay)
end

--[[
	getColorFromString
	
	Exported helper function for converting color strings to Color3 objects.
	See the local getColorFromString function for full documentation.
	
	@function iRichText.getColorFromString
	@param value string | Color3 The color value to convert
	@return Color3 The converted Color3 object
]]
iRichText.getColorFromString = getColorFromString

return iRichText
