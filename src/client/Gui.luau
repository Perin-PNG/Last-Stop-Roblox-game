--!strict
-- Tiny UI helpers so every screen looks the same. All sizes use Scale + offsets that work
-- on phones; text uses TextScaled with a size constraint.

local Players = game:GetService("Players")

local Gui = {}

Gui.Font = Enum.Font.GothamMedium
Gui.FontBold = Enum.Font.GothamBold
Gui.FontMono = Enum.Font.Code
Gui.Colors = {
	Text = Color3.fromRGB(235, 232, 222),
	Dim = Color3.fromRGB(150, 150, 150),
	Panel = Color3.fromRGB(14, 15, 20),
	Accent = Color3.fromRGB(255, 176, 64),
	Danger = Color3.fromRGB(230, 70, 60),
	Good = Color3.fromRGB(90, 210, 120),
	Info = Color3.fromRGB(110, 170, 255),
}

function Gui.playerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

function Gui.screen(name: string, order: number?, ignoreInset: boolean?): ScreenGui
	local existing = Gui.playerGui():FindFirstChild(name)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = name
	sg.ResetOnSpawn = false
	sg.DisplayOrder = order or 1
	sg.IgnoreGuiInset = ignoreInset or false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = Gui.playerGui()
	return sg
end

function Gui.frame(parent: Instance, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Gui.Colors.Panel
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	if props then
		for k, v in props do
			(f :: any)[k] = v
		end
	end
	f.Parent = parent
	return f
end

function Gui.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

function Gui.stroke(parent: Instance, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(70, 70, 80)
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

function Gui.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Gui.Colors.Text
	l.Font = Gui.Font
	l.TextScaled = true
	l.TextWrapped = true
	l.Size = UDim2.fromScale(1, 1)
	if props then
		for k, v in props do
			if k ~= "MaxText" then
				(l :: any)[k] = v
			end
		end
	end
	local maxSize = (props and props.MaxText) or 28
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.MinTextSize = 9
	c.Parent = l
	l.Parent = parent
	return l
end

function Gui.button(parent: Instance, text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(34, 36, 46)
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = Gui.Colors.Text
	b.Font = Gui.FontBold
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Size = UDim2.new(1, 0, 0, 36)
	if props then
		for k, v in props do
			if k ~= "MaxText" then
				(b :: any)[k] = v
			end
		end
	end
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = (props and props.MaxText) or 18
	c.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	Gui.corner(b, 6)
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

function Gui.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.Parent = parent
	return l
end

function Gui.pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

-- "1:05" style time.
function Gui.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Gui
