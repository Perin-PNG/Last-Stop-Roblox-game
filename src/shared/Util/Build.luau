--!strict
-- Small helpers for building the world out of parts in code. Everything the game
-- builds (bus, road, stops, NPC rigs) goes through these so it stays consistent.

local Build = {}

export type PartProps = {
	name: string?,
	size: Vector3?,
	cf: CFrame?,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	anchored: boolean?,
	collide: boolean?,
	shape: Enum.PartType?,
	cast: boolean?, -- CastShadow
	query: boolean?, -- CanQuery
	touch: boolean?, -- CanTouch
	reflectance: number?,
	group: string?, -- collision group
	tag: string?,
	attrs: { [string]: any }?,
}

function Build.part(parent: Instance?, props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.name or "Part"
	p.Size = props.size or Vector3.new(4, 1, 4)
	p.CFrame = props.cf or CFrame.identity
	p.Color = props.color or Color3.fromRGB(120, 120, 120)
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.Anchored = if props.anchored == nil then true else props.anchored
	p.CanCollide = if props.collide == nil then true else props.collide
	p.CastShadow = if props.cast == nil then false else props.cast
	p.CanTouch = if props.touch == nil then false else props.touch
	p.CanQuery = if props.query == nil then true else props.query
	p.Reflectance = props.reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		p.Shape = props.shape
	end
	if props.group then
		p.CollisionGroup = props.group
	end
	if props.tag then
		p:AddTag(props.tag)
	end
	if props.attrs then
		for key, value in props.attrs do
			p:SetAttribute(key, value)
		end
	end
	p.Parent = parent
	return p
end

function Build.wedge(parent: Instance?, props: PartProps): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = props.name or "Wedge"
	p.Size = props.size or Vector3.new(4, 4, 4)
	p.CFrame = props.cf or CFrame.identity
	p.Color = props.color or Color3.fromRGB(120, 120, 120)
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.Anchored = if props.anchored == nil then true else props.anchored
	p.CanCollide = if props.collide == nil then true else props.collide
	p.CastShadow = if props.cast == nil then false else props.cast
	p.CanTouch = false
	if props.group then
		p.CollisionGroup = props.group
	end
	p.Parent = parent
	return p
end

function Build.model(parent: Instance?, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Build.folder(parent: Instance?, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Build.weld(a: BasePart, b: BasePart): WeldConstraint
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
	return w
end

function Build.light(
	parent: Instance,
	kind: "Point" | "Spot" | "Surface",
	color: Color3,
	brightness: number,
	range: number,
	shadows: boolean?
): Light
	local light: Light
	if kind == "Spot" then
		local spot = Instance.new("SpotLight")
		spot.Angle = 70
		spot.Face = Enum.NormalId.Bottom
		light = spot
	elseif kind == "Surface" then
		local surface = Instance.new("SurfaceLight")
		surface.Angle = 90
		surface.Face = Enum.NormalId.Bottom
		light = surface
	else
		light = Instance.new("PointLight")
	end
	light.Color = color
	light.Brightness = brightness;
	(light :: any).Range = range
	light.Shadows = shadows or false
	light.Parent = parent
	return light
end

-- A text sign: a part with a SurfaceGui label on one face.
function Build.sign(
	parent: Instance,
	props: PartProps,
	text: string,
	face: Enum.NormalId?,
	textColor: Color3?,
	font: Enum.Font?
): (Part, TextLabel)
	local p = Build.part(parent, props)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBold
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Parent = gui
	return p, label
end

-- A ProximityPrompt. Prompts work on touch, gamepad and keyboard with no extra code.
function Build.prompt(
	parent: Instance,
	action: string,
	object: string?,
	hold: number?,
	range: number?,
	name: string?
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name or "Prompt"
	prompt.ActionText = action
	prompt.ObjectText = object or ""
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = range or 8
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = parent
	return prompt
end

-- Weld every BasePart in a model to its PrimaryPart (or the first part).
function Build.weldModel(model: Model, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

function Build.setAnchored(model: Instance, anchored: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
end

-- Palette shared by all builders.
Build.Colors = {
	Asphalt = Color3.fromRGB(34, 34, 38),
	Lane = Color3.fromRGB(200, 190, 140),
	Concrete = Color3.fromRGB(110, 110, 112),
	Curb = Color3.fromRGB(150, 150, 150),
	Grass = Color3.fromRGB(32, 44, 30),
	Dirt = Color3.fromRGB(52, 42, 32),
	Sodium = Color3.fromRGB(255, 170, 90),
	Fluor = Color3.fromRGB(210, 255, 230),
	Warm = Color3.fromRGB(255, 220, 170),
	Brick = Color3.fromRGB(92, 52, 44),
	Siding = Color3.fromRGB(150, 145, 130),
	Wood = Color3.fromRGB(96, 70, 48),
	Metal = Color3.fromRGB(140, 145, 150),
	DarkMetal = Color3.fromRGB(60, 62, 66),
	Glass = Color3.fromRGB(120, 150, 160),
	Black = Color3.fromRGB(12, 12, 14),
	White = Color3.fromRGB(230, 230, 225),
	Red = Color3.fromRGB(200, 30, 30),
	BusBody = Color3.fromRGB(210, 205, 190),
	BusStripe = Color3.fromRGB(30, 70, 120),
	Seat = Color3.fromRGB(50, 60, 95),
	Water = Color3.fromRGB(30, 50, 60),
	Corn = Color3.fromRGB(120, 110, 50),
}

return Build
