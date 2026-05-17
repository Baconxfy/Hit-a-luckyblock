-- Complete example of all iRichText tags and combinations
-- Shows every available tag and how to combine them
task.wait(2)
local iRichText = require(game.ReplicatedStorage.Packages.iRichText)

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create main ScreenGui
local screenGui = playerGui:FindFirstChild("ScreenGui") or Instance.new("ScreenGui", playerGui)
screenGui.Name = "iRichTextCompleteExamples"

-- Create ScrollingFrame to contain all examples
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, 0)
scrollFrame.Position = UDim2.new(0, 0, 0, 0)
scrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 8
scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
scrollFrame.Parent = screenGui
screenGui.Enabled = true

-- Create UIListLayout to organize elements
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 15)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Helper function to create a section with title
local function createSection(title, layoutOrder)
	local sectionFrame = Instance.new("Frame")
	sectionFrame.Size = UDim2.new(0, 900, 0, 0)
	sectionFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	sectionFrame.BorderSizePixel = 0
	sectionFrame.LayoutOrder = layoutOrder
	sectionFrame.Parent = scrollFrame

	local sectionTitle = Instance.new("TextLabel")
	sectionTitle.Size = UDim2.new(1, -20, 0, 50)
	sectionTitle.Position = UDim2.new(0, 10, 0, 10)
	sectionTitle.BackgroundTransparency = 1
	sectionTitle.Text = title
	sectionTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
	sectionTitle.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
	sectionTitle.TextSize = 26
	sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	sectionTitle.Parent = sectionFrame

	local sectionListLayout = Instance.new("UIListLayout")
	sectionListLayout.Padding = UDim.new(0, 10)
	sectionListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sectionListLayout.Parent = sectionFrame

	sectionFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		sectionFrame.Size = UDim2.new(0, 900, 0, sectionListLayout.AbsoluteContentSize.Y + 70)
	end)

	return sectionFrame, sectionListLayout
end

-- Helper function to create an example
local function createExample(sectionFrame, description, text, properties, layoutOrder, delay)
	local exampleFrame = Instance.new("Frame")
	exampleFrame.Size = UDim2.new(1, -20, 0, 0)
	exampleFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	exampleFrame.BorderSizePixel = 1
	exampleFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
	exampleFrame.LayoutOrder = layoutOrder
	exampleFrame.Parent = sectionFrame

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -20, 0, 35)
	descLabel.Position = UDim2.new(0, 10, 0, 5)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = description
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	descLabel.TextSize = 14
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = exampleFrame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -20, 0, 100)
	textLabel.Position = UDim2.new(0, 10, 0, 40)
	textLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	textLabel.BorderSizePixel = 1
	textLabel.BorderColor3 = Color3.fromRGB(50, 50, 50)
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	textLabel.TextSize = 18
	textLabel.TextWrapped = true
	textLabel.Parent = exampleFrame

	if delay then
		task.spawn(function()
			task.wait(delay)
			iRichText.EnrichAsync(textLabel, text, properties)
		end)
	else
		iRichText.EnrichAsync(textLabel, text, properties)
	end

	exampleFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		exampleFrame.Size = UDim2.new(1, -20, 0, descLabel.AbsoluteSize.Y + textLabel.AbsoluteSize.Y + 15)
	end)

	return textLabel
end

local layoutOrder = 0

-- ========================================
-- FORMAT TAGS
-- ========================================
local section1, _ = createSection("FORMAT TAGS - Basic Text Formatting", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(section1, "Bold (<b>) - Bold text", "Normal text <b>bold text</b> normal again", nil, 1, 0)
createExample(section1, "Italic (<i>) - Italic text", "Normal text <i>italic text</i> normal again", nil, 2, 0.3)
createExample(
	section1,
	"Underline (<u>) - Underlined text",
	"Normal text <u>underlined text</u> normal again",
	nil,
	3,
	0.6
)
createExample(
	section1,
	"Strikethrough (<s>) - Strikethrough text",
	"Normal text <s>strikethrough text</s> normal again",
	nil,
	4,
	0.9
)
createExample(
	section1,
	"Combined Format Tags - Multiple formats together",
	"Text with <b>bold</b>, <i>italic</i>, <u>underline</u>, and <s>strikethrough</s>",
	nil,
	5,
	1.2
)

-- ========================================
-- FONT TAGS
-- ========================================
local section2, _ = createSection("FONT TAGS - Font Properties", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section2,
	"Font Color - Color attribute",
	'Text with <font color="#FF0000">red color</font> and <font color="#0000FF">blue color</font>',
	nil,
	1,
	1.5
)

createExample(
	section2,
	"Font Size - Size attribute",
	'Text with <font size="32">large size</font> and <font size="14">small size</font>',
	nil,
	2,
	1.8
)

createExample(
	section2,
	"Font Face - Face attribute",
	'Text with <font face="ArialBold">ArialBold font</font> and <font face="SourceSansBold">SourceSansBold font</font>',
	nil,
	3,
	2.1
)

createExample(
	section2,
	"Font All Attributes - Color, size, and face combined",
	'<font color="#00FF00" size="28" face="SourceSansBold">Complete font styling</font>',
	nil,
	4,
	2.4
)

-- ========================================
-- STROKE TAGS
-- ========================================
local section3, _ = createSection("STROKE TAGS - Text Borders", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section3,
	"Stroke Basic - Basic border",
	'Text with <stroke color="#000000" thickness="2">black border</stroke>',
	nil,
	1,
	2.7
)

createExample(
	section3,
	"Stroke Color - Colored border",
	'Text with <stroke color="#FFFF00" thickness="3">yellow border</stroke>',
	nil,
	2,
	3.0
)

createExample(
	section3,
	"Stroke Transparency - Semi-transparent border",
	'Text with <stroke color="#FF0000" thickness="4" transparency="0.5">semi-transparent border</stroke>',
	nil,
	3,
	3.3
)

-- ========================================
-- ANIMATION TAGS - FADE
-- ========================================
local section4, _ = createSection("ANIMATION TAGS - Fade", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(section4, "Fade - Fade-in animation", 'Text with <fade time="1.5">fade animation</fade>', nil, 1, 3.6)

createExample(section4, "Fade Fast - Quick fade", 'Text with <fade time="0.5">quick fade</fade>', nil, 2, 3.9)

-- ========================================
-- ANIMATION TAGS - WIGGLE
-- ========================================
local section5, _ = createSection("ANIMATION TAGS - Wiggle", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section5,
	"Wiggle - Wavy movement",
	'Text with <wiggle amplitude="5" speed="3" time="2">wiggle animation</wiggle>',
	nil,
	1,
	4.2
)

createExample(
	section5,
	"Wiggle Strong - Strong wavy movement",
	'Text with <wiggle amplitude="10" speed="4" time="2.5">strong wiggle</wiggle>',
	nil,
	2,
	4.5
)

-- ========================================
-- ANIMATION TAGS - RAINBOW
-- ========================================
local section6, _ = createSection("ANIMATION TAGS - Rainbow", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section6,
	"Rainbow - Rainbow colors",
	'Text with <rainbow speed="3" time="2">rainbow colors</rainbow>',
	nil,
	1,
	4.8
)

createExample(
	section6,
	"Rainbow Fast - Fast color change",
	'Text with <rainbow speed="5" time="2">fast rainbow</rainbow>',
	nil,
	2,
	5.1
)

-- ========================================
-- ANIMATION TAGS - GRADIENT
-- ========================================
local section6_5, _ = createSection("ANIMATION TAGS - Gradient", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section6_5,
	"Gradient - Custom colors",
	'Text with <gradient colors="#FF0000,#00FF00,#0000FF" speed="2" time="2">custom gradient</gradient>',
	nil,
	1,
	5.15
)

createExample(
	section6_5,
	"Gradient - Named colors",
	'Text with <gradient colors="Red,Blue,Green" speed="2" time="2">named colors gradient</gradient>',
	nil,
	2,
	5.2
)

createExample(
	section6_5,
	"Gradient - Default rainbow",
	'Text with <gradient speed="2" time="2">default gradient</gradient>',
	nil,
	3,
	5.25
)

-- ========================================
-- ANIMATION TAGS - GOLDEN
-- ========================================
local section6_6, _ = createSection("ANIMATION TAGS - Golden", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section6_6,
	"Golden - Golden color gradient",
	'Text with <golden speed="2" time="2">golden text</golden>',
	nil,
	1,
	5.3
)

createExample(
	section6_6,
	"Golden Fast - Fast golden",
	'Text with <golden speed="4" time="2">fast golden</golden>',
	nil,
	2,
	5.35
)

-- ========================================
-- ANIMATION TAGS - SILVER
-- ========================================
local section6_7, _ = createSection("ANIMATION TAGS - Silver", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section6_7,
	"Silver - Silver color gradient",
	'Text with <silver speed="2" time="2">silver text</silver>',
	nil,
	1,
	5.4
)

createExample(
	section6_7,
	"Silver Fast - Fast silver",
	'Text with <silver speed="4" time="2">fast silver</silver>',
	nil,
	2,
	5.45
)

-- ========================================
-- ANIMATION TAGS - BRONZE
-- ========================================
local section6_8, _ = createSection("ANIMATION TAGS - Bronze", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section6_8,
	"Bronze - Bronze color gradient",
	'Text with <bronze speed="2" time="2">bronze text</bronze>',
	nil,
	1,
	5.5
)

createExample(
	section6_8,
	"Bronze Fast - Fast bronze",
	'Text with <bronze speed="4" time="2">fast bronze</bronze>',
	nil,
	2,
	5.55
)

-- ========================================
-- ANIMATION TAGS - SWING
-- ========================================
local section7, _ = createSection("ANIMATION TAGS - Swing", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section7,
	"Swing - Swinging motion",
	'Text with <swing amplitude="30" speed="2" time="2">swinging motion</swing>',
	nil,
	1,
	5.6
)

createExample(
	section7,
	"Swing Wide - Wide swing",
	'Text with <swing amplitude="60" speed="3" time="2.5">wide swing</swing>',
	nil,
	2,
	5.9
)

-- ========================================
-- ANIMATION TAGS - SPIN
-- ========================================
local section8, _ = createSection("ANIMATION TAGS - Spin", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(section8, "Spin - Rotating text", 'Text with <spin speed="1" time="1.5">spinning</spin>', nil, 1, 6.2)

createExample(section8, "Spin Fast - Fast rotation", 'Text with <spin speed="2" time="2">fast spin</spin>', nil, 2, 6.5)

-- ========================================
-- ANIMATION TAGS - SHAKE
-- ========================================
local section9, _ = createSection("ANIMATION TAGS - Shake", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(section9, "Shake - Shaking motion", 'Text with <shake xmag="3" ymag="3">shaking</shake>', nil, 1, 6.8)

createExample(
	section9,
	"Shake Strong - Strong shake",
	'Text with <shake xmag="6" ymag="6">strong shake</shake>',
	nil,
	2,
	7.1
)

-- ========================================
-- ANIMATION TAGS - WAVE
-- ========================================
local section10, _ = createSection("ANIMATION TAGS - Wave", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(section10, "Wave - Vertical wave", 'Text with <wave offset="5">wave animation</wave>', nil, 1, 7.4)

createExample(section10, "Wave Strong - Strong wave", 'Text with <wave offset="10">strong wave</wave>', nil, 2, 7.7)

-- ========================================
-- UTILITY TAGS
-- ========================================
local section11, _ = createSection("UTILITY TAGS - Line Breaks", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section11,
	"Line Break (<br>) - Line breaks",
	"First line<br>Second line<br>Third line<br>Fourth line",
	nil,
	1,
	8.0
)

-- ========================================
-- COMBINATIONS - Format + Font
-- ========================================
local section12, _ = createSection("COMBINATIONS - Format + Font", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(section12, "Bold + Font Color", '<b><font color="#FF0000">Bold red text</font></b>', nil, 1, 8.3)

createExample(section12, "Italic + Font Size", '<i><font size="28">Large italic text</font></i>', nil, 2, 8.6)

createExample(
	section12,
	"Underline + Font Face",
	'<u><font face="ArialBold">Underlined ArialBold</font></u>',
	nil,
	3,
	8.9
)

createExample(
	section12,
	"Multiple Formats + Font",
	'<b><i><font color="#00FF00" size="24">Bold italic green large text</font></i></b>',
	nil,
	4,
	9.2
)

-- ========================================
-- COMBINATIONS - Format + Stroke
-- ========================================
local section13, _ = createSection("COMBINATIONS - Format + Stroke", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section13,
	"Bold + Stroke",
	'<b><stroke color="#0000FF" thickness="2">Bold text with blue border</stroke></b>',
	nil,
	1,
	9.5
)

createExample(
	section13,
	"Italic + Stroke",
	'<i><stroke color="#FF00FF" thickness="3">Italic text with magenta border</stroke></i>',
	nil,
	2,
	9.8
)

-- ========================================
-- COMBINATIONS - Font + Stroke
-- ========================================
local section14, _ = createSection("COMBINATIONS - Font + Stroke", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section14,
	"Font Color + Stroke",
	'<font color="#FFFFFF"><stroke color="#000000" thickness="2">White text with black border</stroke></font>',
	nil,
	1,
	10.1
)

createExample(
	section14,
	"Font Size + Stroke",
	'<font size="32"><stroke color="#FFFF00" thickness="3">Large text with yellow border</stroke></font>',
	nil,
	2,
	10.4
)

-- ========================================
-- COMBINATIONS - Format + Animation
-- ========================================
local section15, _ = createSection("COMBINATIONS - Format + Animation", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(section15, "Bold + Fade", '<b><fade time="1.5">Bold text with fade</fade></b>', nil, 1, 10.7)

createExample(
	section15,
	"Italic + Wiggle",
	'<i><wiggle amplitude="5" time="2">Italic wiggling text</wiggle></i>',
	nil,
	2,
	11.0
)

createExample(
	section15,
	"Underline + Rainbow",
	'<u><rainbow speed="3" time="2">Underlined rainbow text</rainbow></u>',
	nil,
	3,
	11.3
)

createExample(section15, "Bold + Golden", '<b><golden speed="2" time="2">Bold golden text</golden></b>', nil, 4, 11.6)

createExample(
	section15,
	"Italic + Silver",
	'<i><silver speed="2" time="2">Italic silver text</silver></i>',
	nil,
	5,
	11.9
)

createExample(
	section15,
	"Underline + Bronze",
	'<u><bronze speed="2" time="2">Underlined bronze text</bronze></u>',
	nil,
	6,
	12.2
)

-- ========================================
-- COMBINATIONS - Font + Animation
-- ========================================
local section16, _ = createSection("COMBINATIONS - Font + Animation", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section16,
	"Font Color + Fade",
	'<font color="#FF0000"><fade time="1.5">Red text with fade</fade></font>',
	nil,
	1,
	12.5
)

createExample(
	section16,
	"Font Size + Wiggle",
	'<font size="28"><wiggle amplitude="5" time="2">Large wiggling text</wiggle></font>',
	nil,
	2,
	12.8
)

createExample(
	section16,
	"Font Color + Rainbow",
	'<font color="#0000FF"><rainbow speed="3" time="2">Blue base with rainbow</rainbow></font>',
	nil,
	3,
	13.1
)

createExample(
	section16,
	"Font Color + Golden",
	'<font color="#FFD700"><golden speed="2" time="2">Font with golden gradient</golden></font>',
	nil,
	4,
	13.4
)

createExample(
	section16,
	"Font Size + Gradient",
	'<font size="28"><gradient colors="#FF0000,#00FF00,#0000FF" speed="2" time="2">Large gradient text</gradient></font>',
	nil,
	5,
	13.7
)

-- ========================================
-- COMBINATIONS - Stroke + Animation
-- ========================================
local section17, _ = createSection("COMBINATIONS - Stroke + Animation", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section17,
	"Stroke + Fade",
	'<stroke color="#0000FF" thickness="2"><fade time="1.5">Text with border and fade</fade></stroke>',
	nil,
	1,
	14.0
)

createExample(
	section17,
	"Stroke + Wiggle",
	'<stroke color="#FFFF00" thickness="3"><wiggle amplitude="5" time="2">Text with yellow border and wiggle</wiggle></stroke>',
	nil,
	2,
	14.3
)

createExample(
	section17,
	"Stroke + Golden",
	'<stroke color="#000000" thickness="2"><golden speed="2" time="2">Text with border and golden gradient</golden></stroke>',
	nil,
	3,
	14.6
)

-- ========================================
-- COMBINATIONS - Triple Combinations
-- ========================================
local section18, _ = createSection("COMBINATIONS - Triple Combinations", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section18,
	"Bold + Font Color + Stroke",
	'<b><font color="#FFFFFF"><stroke color="#000000" thickness="2">Bold white text with black border</stroke></font></b>',
	nil,
	1,
	14.9
)

createExample(
	section18,
	"Italic + Font Size + Fade",
	'<i><font size="28"><fade time="1.5">Large italic text with fade</fade></font></i>',
	nil,
	2,
	15.2
)

createExample(
	section18,
	"Underline + Font Color + Wiggle",
	'<u><font color="#00FF00"><wiggle amplitude="5" time="2">Underlined green wiggling text</wiggle></font></u>',
	nil,
	3,
	15.5
)

createExample(
	section18,
	"Bold + Font Color + Golden",
	'<b><font color="#FFD700"><golden speed="2" time="2">Bold font with golden gradient</golden></font></b>',
	nil,
	4,
	15.8
)

createExample(
	section18,
	"Italic + Stroke + Silver",
	'<i><stroke color="#000000" thickness="2"><silver speed="2" time="2">Italic text with border and silver gradient</silver></stroke></i>',
	nil,
	5,
	16.1
)

-- ========================================
-- COMBINATIONS - Complex Examples
-- ========================================
local section19, _ = createSection("COMBINATIONS - Complex Examples", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section19,
	"All Formats Together",
	"<b>Bold</b> <i>Italic</i> <u>Underline</u> <s>Strike</s> <b><i>Bold+Italic</i></b>",
	nil,
	1,
	16.4
)

createExample(
	section19,
	"Multiple Animations",
	'<fade time="1">Fade</fade> <wiggle amplitude="5" time="2">Wiggle</wiggle> <rainbow speed="3" time="2">Rainbow</rainbow> <golden speed="2" time="2">Golden</golden>',
	nil,
	2,
	16.7
)

createExample(
	section19,
	"Ultimate Combination - Format + Font + Stroke + Animation",
	'<b><font color="#FF0000" size="24"><stroke color="#000000" thickness="2"><fade time="1.5">Complete styling!</fade></stroke></font></b>',
	nil,
	3,
	17.0
)

createExample(
	section19,
	"Mixed Content - Different styles in same text",
	'Normal text <b>bold</b> normal <font color="#00FF00">green</font> normal <i>italic</i> normal <stroke color="#FF0000" thickness="2">with border</stroke>',
	nil,
	4,
	17.3
)

createExample(
	section19,
	"All Gradient Types",
	'<rainbow speed="2" time="2">Rainbow</rainbow> <golden speed="2" time="2">Golden</golden> <silver speed="2" time="2">Silver</silver> <bronze speed="2" time="2">Bronze</bronze>',
	nil,
	5,
	17.6
)

createExample(
	section19,
	"Complex Gradient Combination",
	'<b><font size="24"><gradient colors="#FF6B6B,#4ECDC4,#45B7D1" speed="2" time="2">Bold large custom gradient</gradient></font></b>',
	nil,
	6,
	17.9
)

-- ========================================
-- PROPERTIES - TypewriteTime
-- ========================================
local section20, _ = createSection("PROPERTIES - TypewriteTime (Letter by Letter)", layoutOrder)
layoutOrder = layoutOrder + 1

createExample(
	section20,
	"TypewriteTime - Slow letter by letter",
	'<fade time="1">Text appears letter by letter</fade>',
	{
		TypewriteTime = 0.1,
	},
	1,
	18.2
)

createExample(
	section20,
	"TypewriteTime - Fast letter by letter",
	'<wiggle amplitude="5" time="2">Fast letter animation</wiggle>',
	{
		TypewriteTime = 0.03,
	},
	2,
	18.5
)

createExample(
	section20,
	"TypewriteTime - Gradient letter by letter",
	'<golden speed="2" time="2">Golden letter by letter</golden>',
	{
		TypewriteTime = 0.05,
	},
	3,
	18.8
)

-- Update ScrollFrame size
scrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
	end)
end)

-- Initialize canvas size
task.wait(0.1)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
