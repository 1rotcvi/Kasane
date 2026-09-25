--!nocheck

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- =========================================================
-- CLEANUP
-- =========================================================

if _G.KasaneCleanup then
	pcall(_G.KasaneCleanup)
end

local Connections = {}
local Threads = {}

local function TrackConnection(connection)
	if typeof(connection) == "RBXScriptConnection" then
		Connections[#Connections + 1] = connection
	end
	return connection
end

local function TrackThread(thread)
	if thread then
		Threads[#Threads + 1] = thread
	end
	return thread
end

_G.KasaneCleanup = function()
	for _, connection in ipairs(Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(Connections)

	for _, thread in ipairs(Threads) do
		pcall(function()
			task.cancel(thread)
		end)
	end

	table.clear(Threads)

	if _G.KasaneClearTPS then
		pcall(_G.KasaneClearTPS)
	end

	if _G.KasaneGui and typeof(_G.KasaneGui) == "Instance" then
		pcall(function()
			_G.KasaneGui:Destroy()
		end)
	end

	if _G.KasaneWindow
		and type(_G.KasaneWindow) == "table"
		and type(_G.KasaneWindow.Destroy) == "function" then
		pcall(function()
			_G.KasaneWindow:Destroy()
		end)
	end
end

-- =========================================================
-- CONFIG
-- =========================================================

local CONFIG = {
	Touchline = {
		Enabled = true,
		SmartGK = true,

		X = 4,
		Y = 7,
		Z = 3,

		GKX = 5,
		GKY = 5.25,
		GKZ = 2,
	},

	TPS = {
		PhysicalEnabled = false,
		PhysicalSize = 5,
		Transparency = 0.45,

		SpatialEnabled = false,
		Radius = 15,
		TickRate = 0.01,
	},

	FFlags = {
		Json = '{"DFIntTargetTimeDelayFacctorTenths":"7"}',
		Interval = 1,
		Mode = "Once",
	},

	UI = {
		Width = 1080,
		Height = 620,
		Keybind = Enum.KeyCode.RightControl,
	},
}

-- =========================================================
-- COLORS
-- =========================================================

local C = {
	Black = Color3.fromHex("#040404"),
	Black2 = Color3.fromHex("#080808"),
	Black3 = Color3.fromHex("#0C0C0C"),

	Surface = Color3.fromHex("#111111"),
	Surface2 = Color3.fromHex("#171717"),
	Surface3 = Color3.fromHex("#1D1D1D"),

	Pink = Color3.fromHex("#C96891"),
	PinkSoft = Color3.fromHex("#D98AAA"),
	PinkMuted = Color3.fromHex("#A95A7B"),
	PinkDark = Color3.fromHex("#70344B"),
	PinkDeep = Color3.fromHex("#351620"),

	Text = Color3.fromHex("#F1F1F1"),
	Muted = Color3.fromHex("#9B9B9B"),
	Dim = Color3.fromHex("#656565"),

	Success = Color3.fromHex("#78C79A"),
	Warning = Color3.fromHex("#D8B66F"),
	Error = Color3.fromHex("#D27488"),
}

-- =========================================================
-- HELPERS
-- =========================================================

local function Safe(callback, ...)
	local args = table.pack(...)

	return pcall(function()
		return callback(table.unpack(args, 1, args.n))
	end)
end

local function GetGuiParent()
	local parent

	Safe(function()
		if type(gethui) == "function" then
			parent = gethui()
		end
	end)

	return parent or CoreGui
end

local function GetViewport()
	local camera = Workspace.CurrentCamera

	if camera then
		return camera.ViewportSize
	end

	return Vector2.new(1280, 720)
end

local function IsMobile()
	local viewport = GetViewport()

	return UserInputService.TouchEnabled
		and (
			not UserInputService.KeyboardEnabled
			or viewport.X < 900
		)
end

local function Number(value, fallback)
	local number = tonumber(value)
	return number or fallback
end

local function Character()
	return LocalPlayer.Character
end

local function IsGoalie()
	local result = false

	Safe(function()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local main = playerGui and playerGui:FindFirstChild("Main")
		local values = main and main:FindFirstChild("Values")
		local goalie = values and values:FindFirstChild("Goalie")

		if goalie then
			result = goalie.Value == true
		end
	end)

	return result
end

-- =========================================================
-- WINDUI
-- =========================================================

local WindUI = loadstring(
	game:HttpGet(
		"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
	)
)()

pcall(function()
	WindUI:AddTheme({
		Name = "Kasane",

		Accent = C.Pink,
		Background = C.Black,
		Outline = C.PinkDark,

		Text = C.Text,
		Placeholder = C.Muted,

		Button = C.Surface,
		Icon = C.PinkSoft,
	})

	WindUI:SetTheme("Kasane")
end)

-- =========================================================
-- TOUCHLINE ENGINE (HARDENED)
-- =========================================================

local Touchline = {
	Detect = nil,
	UpvalueIndex = nil,

	OriginalSize = Vector3.new(2.25, 5.25, 1.5),

	FunctionHooked = false,
	NamecallHooked = false,

	OriginalGetPartBoundsInBox = nil,
	OriginalNamecall = nil,

	MissingFrames = 0,

	ReachCache = Vector3.new(4, 7, 3),
}

local function IsPlausibleSize(vec)
	if typeof(vec) ~= "Vector3" then
		return false
	end

	local m = math.max(vec.X, vec.Y, vec.Z)
	local n = math.min(vec.X, vec.Y, vec.Z)

	if m <= 0 or n <= 0 then
		return false
	end

	-- Hitbox típico de personagem fica entre 0.1 e 200
	if m > 200 or m < 0.1 then
		return false
	end

	return true
end

local function CollectCandidates()
	local seen = {}
	local list = {}

	local function push(container, label)
		if not container then
			return
		end

		if seen[container] then
			return
		end

		seen[container] = true

		local ok, child = pcall(function()
			return container:FindFirstChild("Touch")
		end)

		if ok and child and child:IsA("ModuleScript") then
			list[#list + 1] = { module = child, from = label }
		end

		local ok2, child2 = pcall(function()
			return container:FindFirstChild("Touch", true)
		end)

		if ok2 and child2 and child2:IsA("ModuleScript") and not seen[child2] then
			seen[child2] = true
			list[#list + 1] = { module = child2, from = label .. " (recursive)" }
		end
	end

	push(ReplicatedStorage:FindFirstChild("Modules"), "RS.Modules")
	push(ReplicatedStorage, "RS")
	push(ReplicatedStorage:FindFirstChild("Shared"), "RS.Shared")
	push(ReplicatedStorage:FindFirstChild("Common"), "RS.Common")

	return list
end

local function TryRequireDetect(module)
	local ok, result = pcall(require, module)

	if not ok or type(result) ~= "table" then
		return nil
	end

	if type(result.Detect) == "function" then
		return result.Detect
	end

	for _, v in pairs(result) do
		if type(v) == "function" then
			return v
		end
	end

	return nil
end

local function HuntViaGc()
	if type(getgc) ~= "function" then
		return nil
	end

	local found

	Safe(function()
		for _, value in pairs(getgc(true)) do
			if type(value) == "function" then
				local ok, info = pcall(debug.getinfo, value)
				if ok and type(info) == "table" then
					local name = tostring(info.name or "")

					if name == "Detect"
						or name == "Hit"
						or name == "Check"
						or name == "Verify" then

						found = value
						break
					end
				end
			end
		end
	end)

	return found
end

local function PickUpvalueIndex(fn)
	if type(debug.getupvalue) ~= "function" then
		return nil, nil
	end

	local bestIndex, bestValue

	for index = 1, 40 do
		local ok, _, value = pcall(debug.getupvalue, fn, index)

		if not ok then
			break
		end

		if IsPlausibleSize(value) then
			local aspect = value.X / math.max(value.Z, 0.01)

			-- Personagem é alongado no Y e estreito no Z
			if value.Y >= value.X and aspect >= 0.5 then
				return index, value
			end

			if not bestIndex then
				bestIndex, bestValue = index, value
			end
		end
	end

	if bestIndex then
		return bestIndex, bestValue
	end

	return nil, nil
end

local function ResolveTouchline()
	Touchline.Detect = nil
	Touchline.UpvalueIndex = nil

	local candidates = CollectCandidates()

	for _, entry in ipairs(candidates) do
		local detect = TryRequireDetect(entry.module)

		if detect then
			Touchline.Detect = detect
			break
		end
	end

	if not Touchline.Detect then
		Touchline.Detect = HuntViaGc()
	end

	if not Touchline.Detect then
		return false
	end

	local index, value = PickUpvalueIndex(Touchline.Detect)

	if index and value then
		Touchline.UpvalueIndex = index
		Touchline.OriginalSize = value
		return true
	end

	return false
end

local function GetReachVector()
	if CONFIG.Touchline.SmartGK and IsGoalie() then
		return Vector3.new(
			Number(CONFIG.Touchline.GKX, 5),
			Number(CONFIG.Touchline.GKY, 5.25),
			Number(CONFIG.Touchline.GKZ, 2)
		)
	end

	return Vector3.new(
		Number(CONFIG.Touchline.X, 4),
		Number(CONFIG.Touchline.Y, 7),
		Number(CONFIG.Touchline.Z, 3)
	)
end

local function IsInternalCall()
	if type(checkcaller) == "function" then
		return checkcaller() == true
	end

	return false
end

local function ApplyTouchlineUpvalue()
	if not Touchline.Detect or not Touchline.UpvalueIndex then
		return
	end

	if type(debug.setupvalue) ~= "function" then
		return
	end

	local target

	if CONFIG.Touchline.Enabled then
		target = GetReachVector()
		Touchline.ReachCache = target
	else
		target = Touchline.OriginalSize
	end

	pcall(
		debug.setupvalue,
		Touchline.Detect,
		Touchline.UpvalueIndex,
		target
	)
end

local function InstallFunctionHook()
	if Touchline.FunctionHooked then
		return
	end

	if type(hookfunction) ~= "function" then
		return
	end

	local original = Workspace.GetPartBoundsInBox

	if type(original) ~= "function" then
		return
	end

	local ok, hooked = pcall(function()
		return hookfunction(original, function(self, cframe, size, overlapParams, ...)
			if CONFIG.Touchline.Enabled and not IsInternalCall() then
				return Touchline.OriginalGetPartBoundsInBox(
					self,
					cframe,
					Touchline.ReachCache,
					overlapParams,
					...
				)
			end

			return Touchline.OriginalGetPartBoundsInBox(
				self,
				cframe,
				size,
				overlapParams,
				...
			)
		end)
	end)

	if ok and type(hooked) == "function" then
		Touchline.OriginalGetPartBoundsInBox = hooked
		Touchline.FunctionHooked = true
	end
end

local function InstallNamecallHook()
	if Touchline.NamecallHooked then
		return
	end

	if type(hookmetamethod) ~= "function" then
		return
	end

	local ok = pcall(function()
		local oldNamecall

		oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()

			if self == Workspace
				and (method == "GetPartBoundsInBox" or method == "getPartBoundsInBox")
				and CONFIG.Touchline.Enabled
				and not IsInternalCall() then

				local args = table.pack(...)
				args[2] = Touchline.ReachCache

				return oldNamecall(self, table.unpack(args, 1, args.n))
			end

			return oldNamecall(self, ...)
		end))

		Touchline.OriginalNamecall = oldNamecall
	end)

	if ok then
		Touchline.NamecallHooked = true
	end
end

local function InstallHooks()
	InstallFunctionHook()

	if not Touchline.FunctionHooked then
		InstallNamecallHook()
	end
end

local function RefreshTouchline()
	local resolved = ResolveTouchline()

	if resolved then
		Touchline.MissingFrames = 0
	else
		Touchline.MissingFrames += 1
	end

	InstallHooks()
	ApplyTouchlineUpvalue()
end

RefreshTouchline()

TrackConnection(RunService.Stepped:Connect(function()
	if not Touchline.Detect or not Touchline.UpvalueIndex then
		Touchline.MissingFrames += 1

		if Touchline.MissingFrames > 60 then
			Touchline.MissingFrames = 0
			RefreshTouchline()
		end

		return
	end

	Touchline.ReachCache = CONFIG.Touchline.Enabled and GetReachVector() or Touchline.OriginalSize
	ApplyTouchlineUpvalue()
end))

TrackConnection(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F3 then
		CONFIG.Touchline.Enabled = not CONFIG.Touchline.Enabled
		ApplyTouchlineUpvalue()
	end
end))

-- =========================================================
-- TPS PHYSICAL
-- =========================================================

local TPSConnections = {}

local function GetFootballs()
	local folder = Workspace:FindFirstChild("Footballs")

	local balls = {}

	if not folder then
		return balls
	end

	for _, object in ipairs(folder:GetChildren()) do
		if object:IsA("BasePart") then
			balls[#balls + 1] = object
		end
	end

	return balls
end

local function ApplyTPSPhysical(ball)
	if not ball
		or not ball.Parent
		or not ball:IsA("BasePart") then
		return
	end

	local marker = ball:FindFirstChild("KasaneOriginal")

	if not marker then
		marker = Instance.new("Folder")
		marker.Name = "KasaneOriginal"

		marker:SetAttribute("Size", ball.Size)
		marker:SetAttribute("Transparency", ball.Transparency)
		marker:SetAttribute("CanCollide", ball.CanCollide)

		marker.Parent = ball
	end

	if not CONFIG.TPS.PhysicalEnabled then
		return
	end

	local size = math.max(0.1, Number(CONFIG.TPS.PhysicalSize, 5))

	ball.Size = Vector3.new(size, size, size)

	ball.Transparency = math.clamp(
		Number(CONFIG.TPS.Transparency, 0.45),
		0,
		1
	)

	ball.CanCollide = false

	local visual = ball:FindFirstChild("KasaneVisual")

	if not visual then
		visual = Instance.new("SelectionBox")
		visual.Name = "KasaneVisual"
		visual.Adornee = ball
		visual.LineThickness = 0.03
		visual.Color3 = C.Pink
		visual.SurfaceTransparency = 1
		visual.Parent = ball
	end
end

local function ClearTPSPhysical()
	for _, ball in ipairs(GetFootballs()) do
		local marker = ball:FindFirstChild("KasaneOriginal")

		if marker then
			local size = marker:GetAttribute("Size")
			local transparency = marker:GetAttribute("Transparency")
			local canCollide = marker:GetAttribute("CanCollide")

			if typeof(size) == "Vector3" then
				ball.Size = size
			end

			if type(transparency) == "number" then
				ball.Transparency = transparency
			end

			if type(canCollide) == "boolean" then
				ball.CanCollide = canCollide
			end

			local visual = ball:FindFirstChild("KasaneVisual")

			if visual then
				pcall(function()
					visual:Destroy()
				end)
			end

			pcall(function()
				marker:Destroy()
			end)
		end
	end
end

_G.KasaneClearTPS = ClearTPSPhysical

local function ToggleTPSPhysical(enabled)
	CONFIG.TPS.PhysicalEnabled = enabled

	for _, connection in ipairs(TPSConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(TPSConnections)

	if not enabled then
		ClearTPSPhysical()
		return
	end

	for _, ball in ipairs(GetFootballs()) do
		ApplyTPSPhysical(ball)
	end

	local folder = Workspace:FindFirstChild("Footballs")

	if folder then
		local connection = folder.ChildAdded:Connect(function(object)
			if object:IsA("BasePart") then
				task.defer(ApplyTPSPhysical, object)
			end
		end)

		TPSConnections[#TPSConnections + 1] = connection
		TrackConnection(connection)
	end
end

-- =========================================================
-- TPS SPATIAL
-- =========================================================

local Spatial = {
	LastTick = 0,
	Connection = nil,
	Overlap = OverlapParams.new(),
}

Spatial.Overlap.FilterType = Enum.RaycastFilterType.Include

function Spatial:GetFoot(character, humanoid)
	local settings = Lighting:FindFirstChild(LocalPlayer.Name)

	local preferred = settings and settings:FindFirstChild("PreferredFoot")

	local right = not preferred or preferred.Value == 1

	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return character:FindFirstChild(right and "Right Leg" or "Left Leg")
	end

	return character:FindFirstChild(right and "RightLowerLeg" or "LeftLowerLeg")
end

function Spatial:Tick()
	local now = os.clock()

	local rate = math.max(0.01, Number(CONFIG.TPS.TickRate, 0.01))

	if now - self.LastTick < rate then
		return
	end

	self.LastTick = now

	local character = Character()

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not (humanoid and humanoid.Health > 0 and root) then
		return
	end

	local system = Workspace:FindFirstChild("TPSSystem")
	local ball = system and system:FindFirstChild("TPS")

	if not ball then
		return
	end

	self.Overlap.FilterDescendantsInstances = { ball }

	local hits = Workspace:GetPartBoundsInRadius(
		root.Position,
		math.max(0, Number(CONFIG.TPS.Radius, 15)),
		self.Overlap
	)

	if #hits <= 0 then
		return
	end

	local foot = self:GetFoot(character, humanoid)

	if not foot or type(firetouchinterest) ~= "function" then
		return
	end

	pcall(function()
		firetouchinterest(foot, ball, 0)
		firetouchinterest(foot, ball, 1)
	end)
end

function Spatial:Toggle(enabled)
	CONFIG.TPS.SpatialEnabled = enabled

	if enabled then
		if not self.Connection then
			self.Connection = TrackConnection(
				RunService.Heartbeat:Connect(function()
					self:Tick()
				end)
			)
		end
	elseif self.Connection then
		pcall(function()
			self.Connection:Disconnect()
		end)

		self.Connection = nil
	end
end

-- =========================================================
-- FFLAG ENGINE
-- =========================================================

local FlagEngine = {}
FlagEngine.__index = FlagEngine

local Prefixes = {
	"^DFInt",
	"^DFFlag",
	"^DFlag",
	"^FFlag",
	"^FInt",
	"^DFint",
}

local Blocked = {
	"FString",
	"FFString",
	"FLog",
}

function FlagEngine.new()
	return setmetatable({
		Running = false,
		Worker = nil,
		Queue = {},
		Mode = "Once",
		Interval = 1,
	}, FlagEngine)
end

function FlagEngine:Normalize(name)
	local output = tostring(name)

	for _, prefix in ipairs(Prefixes) do
		output = output:gsub(prefix, "")
	end

	return output
end

function FlagEngine:Parse(json)
	if type(json) ~= "string" or json == "" then
		return false, "JSON vazio", 0
	end

	local decoded

	local ok = pcall(function()
		decoded = HttpService:JSONDecode(json)
	end)

	if not ok or type(decoded) ~= "table" then
		return false, "JSON invalido", 0
	end

	local parsed = {}
	local rejected = 0

	for name, value in pairs(decoded) do
		local key = tostring(name)
		local denied = false

		for _, blocked in ipairs(Blocked) do
			if key:find(blocked, 1, true) then
				denied = true
				break
			end
		end

		if denied then
			rejected += 1
		else
			parsed[#parsed + 1] = {
				Original = key,
				Clean = self:Normalize(key),
				Value = tostring(value),
			}
		end
	end

	if #parsed == 0 then
		return false, "Nenhuma flag valida", rejected
	end

	return true, parsed, rejected
end

function FlagEngine:QueueFlags(flags)
	table.clear(self.Queue)

	for _, flag in ipairs(flags) do
		self.Queue[#self.Queue + 1] = flag
	end
end

function FlagEngine:Clear()
	table.clear(self.Queue)
end

function FlagEngine:Stop()
	self.Running = false

	if self.Worker then
		pcall(task.cancel, self.Worker)
		self.Worker = nil
	end
end

function FlagEngine:Start(callback)
	if self.Running then
		return false
	end

	if #self.Queue == 0 then
		if callback then
			callback("error", "Queue vazia.")
		end

		return false
	end

	self.Running = true

	self.Worker = task.spawn(function()
		while self.Running do
			for _, flag in ipairs(self.Queue) do
				if not self.Running then
					break
				end

				local success = pcall(function()
					if type(setfflag) ~= "function" then
						error("setfflag indisponivel")
					end

					setfflag(flag.Clean, flag.Value)
				end)

				if callback then
					callback(
						success and "success" or "error",
						success
							and string.format("%s = %s", flag.Original, flag.Value)
							or ("Falha: " .. flag.Original)
					)
				end
			end

			if self.Mode == "Once" then
				break
			end

			task.wait(math.max(0.05, Number(self.Interval, 1)))
		end

		self.Running = false
		self.Worker = nil
	end)

	TrackThread(self.Worker)

	return true
end

local Engine = FlagEngine.new()

-- =========================================================
-- LOG
-- =========================================================

local Logs = {}

local function Log(message, state)
	local prefix =
		state == "success" and "[OK]"
		or state == "error" and "[ERR]"
		or state == "warn" and "[WARN]"
		or "[INFO]"

	Logs[#Logs + 1] = string.format(
		"[%s] %s %s",
		os.date("%H:%M:%S"),
		prefix,
		tostring(message)
	)

	if #Logs > 200 then
		table.remove(Logs, 1)
	end
end

-- =========================================================
-- RESPONSIVE WINDOW
-- =========================================================

local Mobile = IsMobile()
local Viewport = GetViewport()

local function GetResponsiveSize()
	Viewport = GetViewport()
	Mobile = IsMobile()

	if not Mobile then
		return UDim2.fromOffset(CONFIG.UI.Width, CONFIG.UI.Height)
	end

	local width = math.clamp(math.floor(Viewport.X * 0.82), 320, 920)
	local height = math.clamp(math.floor(Viewport.Y * 0.58), 320, 520)

	return UDim2.fromOffset(width, height)
end

-- =========================================================
-- WINDOW
-- =========================================================

local Window = WindUI:CreateWindow({
	Title = "KASANE HUB",
	Icon = "sparkles",
	Author = "Touchline x TPS",
	Folder = "KasaneHub",
	Size = GetResponsiveSize(),

	MinSize = Mobile and Vector2.new(300, 300) or Vector2.new(760, 440),
	MaxSize = Mobile and Vector2.new(920, 520) or Vector2.new(1280, 800),

	Resizable = not Mobile,
	SideBarWidth = Mobile and 145 or 205,
	HideSearchBar = Mobile,
	ScrollBarEnabled = true,
	NewElements = true,

	OpenButton = { Enabled = false },

	Topbar = {
		Height = Mobile and 40 or 46,
		ButtonsType = "Default",
	},
})

_G.KasaneWindow = Window

Window:Tag({
	Title = "KASANE",
	Icon = "sparkles",
	Color = C.PinkDeep,
	Border = true,
})

if not Mobile then
	Window:Tag({
		Title = "ONLINE",
		Icon = "activity",
		Color = C.Black3,
		Border = true,
	})
end

pcall(function()
	if Mobile then
		local shortAxis = math.min(Viewport.X, Viewport.Y)

		local scale =
			shortAxis <= 430 and 0.76
			or shortAxis <= 600 and 0.80
			or 0.84

		Window:SetUIScale(scale)
	end
end)

TrackConnection(
	Workspace.CurrentCamera
		and Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.delay(0.15, function()
				if not _G.KasaneWindow then
					return
				end

				local newMobile = IsMobile()

				if newMobile ~= Mobile then
					Mobile = newMobile

					pcall(function()
						Window:SetUIScale(Mobile and 0.80 or 1)
						Window:SetSize(GetResponsiveSize())
					end)
				end
			end)
		end)
)

-- =========================================================
-- CUSTOM LAUNCHER
-- =========================================================

local function CreateLauncher()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KasaneLauncher"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = GetGuiParent()

	_G.KasaneGui = gui

	local button = Instance.new("TextButton")
	button.Name = "Launcher"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, Mobile and 10 or 16)
	button.Size = Mobile and UDim2.fromOffset(144, 34) or UDim2.fromOffset(178, 40)
	button.BackgroundColor3 = C.Black
	button.BackgroundTransparency = 0.02
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = 100
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.Black2),
		ColorSequenceKeypoint.new(0.65, C.Black3),
		ColorSequenceKeypoint.new(1, C.PinkDeep),
	})
	gradient.Rotation = 90
	gradient.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = C.PinkMuted
	stroke.Thickness = Mobile and 1.1 or 1.4
	stroke.Transparency = 0.08
	stroke.Parent = button

	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(Mobile and 10 or 13, 0)
	icon.Size = UDim2.fromOffset(Mobile and 22 or 27, button.Size.Y.Offset)
	icon.Text = "✦"
	icon.TextColor3 = C.PinkSoft
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = Mobile and 15 or 18
	icon.ZIndex = 101
	icon.Parent = button

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(Mobile and 35 or 43, 0)
	title.Size = UDim2.fromOffset(Mobile and 72 or 90, button.Size.Y.Offset)
	title.Text = "KASANE"
	title.TextColor3 = C.Text
	title.Font = Enum.Font.GothamMedium
	title.TextSize = Mobile and 11 or 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 101
	title.Parent = button

	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(Mobile and 5 or 7, Mobile and 5 or 7)
	dot.Position = UDim2.new(1, Mobile and -29 or -38, 0.5, Mobile and -2.5 or -3.5)
	dot.BackgroundColor3 = C.PinkSoft
	dot.BorderSizePixel = 0
	dot.ZIndex = 101
	dot.Parent = button

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Position = UDim2.new(1, Mobile and -19 or -24, 0, 0)
	arrow.Size = UDim2.fromOffset(Mobile and 12 or 16, button.Size.Y.Offset)
	arrow.Text = "›"
	arrow.TextColor3 = C.Muted
	arrow.Font = Enum.Font.GothamMedium
	arrow.TextSize = Mobile and 16 or 20
	arrow.ZIndex = 101
	arrow.Parent = button

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local dragging = false
	local moved = false
	local dragInput
	local dragStart
	local startPosition

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then

			dragging = true
			moved = false
			dragStart = input.Position
			startPosition = button.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					dragInput = nil
				end
			end)
		end
	end)

	button.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	TrackConnection(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		local valid = input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch

		if not valid then
			return
		end

		if dragInput ~= nil and input ~= dragInput
			and input.UserInputType == Enum.UserInputType.MouseMovement then
			return
		end

		local delta = input.Position - dragStart

		if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
			moved = true
		end

		button.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end))

	button.MouseEnter:Connect(function()
		TweenService:Create(
			scale,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1.04 }
		):Play()

		TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0 }):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(
			scale,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()

		TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0.08 }):Play()
	end)

	button.Activated:Connect(function()
		if moved then
			moved = false
			return
		end

		pcall(function()
			Window:Toggle()
		end)
	end)
end

CreateLauncher()

-- =========================================================
-- SECTIONS
-- =========================================================

local Core = Window:Section({ Title = "CORE", Opened = true })
local Tools = Window:Section({ Title = "TOOLS", Opened = true })
local System = Window:Section({ Title = "SYSTEM", Opened = true })

-- =========================================================
-- TABS
-- =========================================================

local Home = Core:Tab({ Title = "Home", Icon = "house" })
local Touch = Core:Tab({ Title = "Touchline", Icon = "crosshair" })
local TPS = Core:Tab({ Title = "TPS", Icon = "circle-dot" })
local Presets = Tools:Tab({ Title = "Presets", Icon = "bookmark" })
local FFlags = Tools:Tab({ Title = "FFlags", Icon = "flag" })
local LogsTab = Tools:Tab({ Title = "Logs", Icon = "terminal" })
local Settings = System:Tab({ Title = "Settings", Icon = "settings" })

-- =========================================================
-- HOME
-- =========================================================

Home:Paragraph({
	Title = "KASANE HUB",
	Desc = "Touchline x TPS\nBlack Rose",
	Image = "sparkles",
	ImageSize = Mobile and 20 or 24,
	Color = C.Pink,
})

Home:Divider()

Home:Paragraph({
	Title = "SYSTEM",
	Desc = "Ready",
	Image = "activity",
	ImageSize = 19,
	Color = C.Pink,
})

Home:Section({ Title = "QUICK CONTROL", TextSize = Mobile and 15 or 18 })

Home:Toggle({
	Title = "Touchline",
	Desc = "Enable reach.",
	Icon = "crosshair",
	Value = CONFIG.Touchline.Enabled,
	Callback = function(value)
		CONFIG.Touchline.Enabled = value
		ApplyTouchlineUpvalue()
	end,
})

Home:Toggle({
	Title = "Smart GK",
	Desc = "Automatic GK profile.",
	Icon = "goal",
	Value = CONFIG.Touchline.SmartGK,
	Callback = function(value)
		CONFIG.Touchline.SmartGK = value
		ApplyTouchlineUpvalue()
	end,
})

Home:Toggle({
	Title = "TPS Physical",
	Desc = "Physical ball.",
	Icon = "circle-dot",
	Value = CONFIG.TPS.PhysicalEnabled,
	Callback = function(value)
		ToggleTPSPhysical(value)
	end,
})

Home:Toggle({
	Title = "TPS Spatial",
	Desc = "Spatial touch.",
	Icon = "radio",
	Value = CONFIG.TPS.SpatialEnabled,
	Callback = function(value)
		Spatial:Toggle(value)
	end,
})

Home:Button({
	Title = "Refresh",
	Desc = "Refresh Touchline.",
	Icon = "refresh-cw",
	Callback = function()
		RefreshTouchline()
		Log("Touchline refreshed.", "success")
	end,
})

Home:Section({ Title = "BUILD", TextSize = Mobile and 15 or 18 })

Home:Paragraph({
	Title = "KASANE / BLACK ROSE",
	Desc = "WindUI\nv1.0.0",
	Image = "code-2",
	ImageSize = 20,
	Color = C.PinkSoft,
})

-- =========================================================
-- TOUCHLINE
-- =========================================================

Touch:Section({ Title = "PLAYER XYZ", TextSize = Mobile and 15 or 18 })

Touch:Toggle({
	Title = "Enable Reach",
	Desc = "Enable Touchline.",
	Icon = "crosshair",
	Value = CONFIG.Touchline.Enabled,
	Callback = function(value)
		CONFIG.Touchline.Enabled = value
		ApplyTouchlineUpvalue()
	end,
})

Touch:Toggle({
	Title = "Smart GK",
	Desc = "Automatic goalkeeper XYZ.",
	Icon = "goal",
	Value = CONFIG.Touchline.SmartGK,
	Callback = function(value)
		CONFIG.Touchline.SmartGK = value
		ApplyTouchlineUpvalue()
	end,
})

Touch:Input({
	Title = "Reach X",
	Desc = "Player X.",
	Value = tostring(CONFIG.Touchline.X),
	Placeholder = "4",
	InputIcon = "move-horizontal",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.Touchline.X = number
			ApplyTouchlineUpvalue()
		end
	end,
})

Touch:Input({
	Title = "Reach Y",
	Desc = "Player Y.",
	Value = tostring(CONFIG.Touchline.Y),
	Placeholder = "7",
	InputIcon = "move-vertical",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.Touchline.Y = number
			ApplyTouchlineUpvalue()
		end
	end,
})

Touch:Input({
	Title = "Reach Z",
	Desc = "Player Z.",
	Value = tostring(CONFIG.Touchline.Z),
	Placeholder = "3",
	InputIcon = "move",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.Touchline.Z = number
			ApplyTouchlineUpvalue()
		end
	end,
})

Touch:Section({ Title = "GOALKEEPER XYZ", TextSize = Mobile and 15 or 18 })

Touch:Input({
	Title = "GK Reach X",
	Desc = "GK X.",
	Value = tostring(CONFIG.Touchline.GKX),
	Placeholder = "5",
	InputIcon = "move-horizontal",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.Touchline.GKX = number
			ApplyTouchlineUpvalue()
		end
	end,
})

Touch:Input({
	Title = "GK Reach Y",
	Desc = "GK Y.",
	Value = tostring(CONFIG.Touchline.GKY),
	Placeholder = "5.25",
	InputIcon = "move-vertical",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.Touchline.GKY = number
			ApplyTouchlineUpvalue()
		end
	end,
})

Touch:Input({
	Title = "GK Reach Z",
	Desc = "GK Z.",
	Value = tostring(CONFIG.Touchline.GKZ),
	Placeholder = "2",
	InputIcon = "move",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.Touchline.GKZ = number
			ApplyTouchlineUpvalue()
		end
	end,
})

Touch:Section({ Title = "ACTIONS", TextSize = Mobile and 15 or 18 })

Touch:Button({
	Title = "Apply XYZ",
	Desc = "Apply current values.",
	Icon = "check",
	Callback = function()
		CONFIG.Touchline.Enabled = true
		ApplyTouchlineUpvalue()

		WindUI:Notify({
			Title = "Touchline",
			Content = "XYZ applied.",
			Icon = "check",
			Duration = 2,
		})
	end,
})

Touch:Button({
	Title = "Re-Hook",
	Desc = "Refresh Detect.",
	Icon = "refresh-cw",
	Callback = function()
		RefreshTouchline()
		Log("Touchline re-hooked.", "success")
	end,
})

-- =========================================================
-- TPS
-- =========================================================

TPS:Section({ Title = "PHYSICAL", TextSize = Mobile and 15 or 18 })

TPS:Toggle({
	Title = "Physical Reach",
	Desc = "Resize football.",
	Icon = "maximize-2",
	Value = CONFIG.TPS.PhysicalEnabled,
	Callback = function(value)
		ToggleTPSPhysical(value)
	end,
})

TPS:Input({
	Title = "Ball Size",
	Desc = "Ball size.",
	Value = tostring(CONFIG.TPS.PhysicalSize),
	Placeholder = "5",
	InputIcon = "circle",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.TPS.PhysicalSize = number
			if CONFIG.TPS.PhysicalEnabled then
				ToggleTPSPhysical(true)
			end
		end
	end,
})

TPS:Input({
	Title = "Transparency",
	Desc = "0 - 1.",
	Value = tostring(CONFIG.TPS.Transparency),
	Placeholder = "0.45",
	InputIcon = "eye-off",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.TPS.Transparency = math.clamp(number, 0, 1)
			if CONFIG.TPS.PhysicalEnabled then
				ToggleTPSPhysical(true)
			end
		end
	end,
})

TPS:Section({ Title = "SPATIAL", TextSize = Mobile and 15 or 18 })

TPS:Toggle({
	Title = "Spatial Touch",
	Desc = "Enable spatial scan.",
	Icon = "radio",
	Value = CONFIG.TPS.SpatialEnabled,
	Callback = function(value)
		Spatial:Toggle(value)
	end,
})

TPS:Input({
	Title = "Radius",
	Desc = "Spatial radius.",
	Value = tostring(CONFIG.TPS.Radius),
	Placeholder = "15",
	InputIcon = "scan",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.TPS.Radius = math.max(0, number)
		end
	end,
})

TPS:Input({
	Title = "Tick Rate",
	Desc = "Update interval.",
	Value = tostring(CONFIG.TPS.TickRate),
	Placeholder = "0.01",
	InputIcon = "timer",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.TPS.TickRate = math.max(0.01, number)
		end
	end,
})

TPS:Button({
	Title = "Restore",
	Desc = "Restore football.",
	Icon = "rotate-ccw",
	Callback = function()
		ToggleTPSPhysical(false)
		Spatial:Toggle(false)
		Log("TPS restored.", "success")
	end,
})

-- =========================================================
-- PRESETS
-- =========================================================

local PRESETS = {
	Default = {
		X = 4, Y = 7, Z = 3,
		GKX = 5, GKY = 5.25, GKZ = 2,
		Ball = 5, Radius = 15, Tick = 0.01,
	},
	Compact = {
		X = 3, Y = 5, Z = 2,
		GKX = 4, GKY = 5, GKZ = 2,
		Ball = 4, Radius = 10, Tick = 0.05,
	},
	Extended = {
		X = 6, Y = 9, Z = 5,
		GKX = 6, GKY = 7, GKZ = 4,
		Ball = 8, Radius = 25, Tick = 0.01,
	},
}

local PresetNames = {}

for name in pairs(PRESETS) do
	PresetNames[#PresetNames + 1] = name
end

table.sort(PresetNames)

Presets:Section({ Title = "PROFILES", TextSize = Mobile and 15 or 18 })

Presets:Dropdown({
	Title = "Profile",
	Desc = "Select profile.",
	Values = PresetNames,
	Value = "Default",
	AllowNone = false,
	Callback = function(name)
		local profile = PRESETS[name]
		if not profile then
			return
		end

		CONFIG.Touchline.X = profile.X
		CONFIG.Touchline.Y = profile.Y
		CONFIG.Touchline.Z = profile.Z
		CONFIG.Touchline.GKX = profile.GKX
		CONFIG.Touchline.GKY = profile.GKY
		CONFIG.Touchline.GKZ = profile.GKZ
		CONFIG.TPS.PhysicalSize = profile.Ball
		CONFIG.TPS.Radius = profile.Radius
		CONFIG.TPS.TickRate = profile.Tick

		ApplyTouchlineUpvalue()

		Log("Profile loaded: " .. name, "success")

		WindUI:Notify({
			Title = "Kasane",
			Content = name .. " loaded.",
			Icon = "bookmark-check",
			Duration = 2,
		})
	end,
})

Presets:Button({
	Title = "Default",
	Desc = "Restore defaults.",
	Icon = "rotate-ccw",
	Callback = function()
		local profile = PRESETS.Default
		CONFIG.Touchline.X = profile.X
		CONFIG.Touchline.Y = profile.Y
		CONFIG.Touchline.Z = profile.Z
		CONFIG.Touchline.GKX = profile.GKX
		CONFIG.Touchline.GKY = profile.GKY
		CONFIG.Touchline.GKZ = profile.GKZ
		CONFIG.TPS.PhysicalSize = profile.Ball
		CONFIG.TPS.Radius = profile.Radius
		CONFIG.TPS.TickRate = profile.Tick
		ApplyTouchlineUpvalue()
	end,
})

Presets:Button({
	Title = "Extended",
	Desc = "Extended profile.",
	Icon = "maximize",
	Callback = function()
		local profile = PRESETS.Extended
		CONFIG.Touchline.X = profile.X
		CONFIG.Touchline.Y = profile.Y
		CONFIG.Touchline.Z = profile.Z
		CONFIG.Touchline.GKX = profile.GKX
		CONFIG.Touchline.GKY = profile.GKY
		CONFIG.Touchline.GKZ = profile.GKZ
		CONFIG.TPS.PhysicalSize = profile.Ball
		CONFIG.TPS.Radius = profile.Radius
		CONFIG.TPS.TickRate = profile.Tick
		ApplyTouchlineUpvalue()
	end,
})

-- =========================================================
-- FFLAGS
-- =========================================================

FFlags:Section({ Title = "JSON", TextSize = Mobile and 15 or 18 })

FFlags:Input({
	Title = "Flag JSON",
	Desc = "JSON input.",
	Value = CONFIG.FFlags.Json,
	Placeholder = '{"DFIntTargetTimeDelayFacctorTenths":"7"}',
	InputIcon = "braces",
	Type = "Textarea",
	Callback = function(value)
		CONFIG.FFlags.Json = value
	end,
})

FFlags:Toggle({
	Title = "Loop Mode",
	Desc = "Repeat queue.",
	Icon = "repeat",
	Value = false,
	Callback = function(value)
		CONFIG.FFlags.Mode = value and "Loop" or "Once"
		Engine.Mode = CONFIG.FFlags.Mode
	end,
})

FFlags:Input({
	Title = "Interval",
	Desc = "Loop delay.",
	Value = tostring(CONFIG.FFlags.Interval),
	Placeholder = "1",
	InputIcon = "timer",
	Type = "Input",
	Callback = function(value)
		local number = tonumber(value)
		if number then
			CONFIG.FFlags.Interval = math.max(0.05, number)
			Engine.Interval = CONFIG.FFlags.Interval
		end
	end,
})

FFlags:Section({ Title = "ACTIONS", TextSize = Mobile and 15 or 18 })

FFlags:Button({
	Title = "Parse",
	Desc = "Validate and queue.",
	Icon = "scan",
	Callback = function()
		local ok, parsed, rejected = Engine:Parse(CONFIG.FFlags.Json)

		if not ok then
			Log(tostring(parsed), "error")

			WindUI:Notify({
				Title = "FFlag",
				Content = tostring(parsed),
				Icon = "x",
				Duration = 3,
			})

			return
		end

		Engine:QueueFlags(parsed)

		Log(
			string.format("Queued %d | Rejected %d", #parsed, rejected),
			"success"
		)
	end,
})

FFlags:Button({
	Title = "Start",
	Desc = "Start worker.",
	Icon = "play",
	Callback = function()
		Engine:Start(function(state, message)
			Log(message, state)
		end)
	end,
})

FFlags:Button({
	Title = "Stop",
	Desc = "Stop worker.",
	Icon = "square",
	Callback = function()
		Engine:Stop()
		Log("FFlag engine stopped.", "info")
	end,
})

FFlags:Button({
	Title = "Clear Queue",
	Desc = "Clear queue.",
	Icon = "trash-2",
	Callback = function()
		Engine:Clear()
		Log("Queue cleared.", "info")
	end,
})

-- =========================================================
-- LOGS
-- =========================================================

LogsTab:Section({ Title = "CONSOLE", TextSize = Mobile and 15 or 18 })

local LogParagraph = LogsTab:Paragraph({
	Title = "Kasane Console",
	Desc = "No entries.",
	Image = "terminal",
	ImageSize = 20,
	Color = C.Pink,
})

local function RefreshLogs()
	local total = #Logs
	local first = math.max(1, total - 35)

	local output = {}

	for index = first, total do
		output[#output + 1] = Logs[index]
	end

	pcall(function()
		LogParagraph:SetDesc(
			#output > 0
				and table.concat(output, "\n")
				or "No entries."
		)
	end)
end

local BaseLog = Log

Log = function(message, state)
	BaseLog(message, state)
	RefreshLogs()
end

LogsTab:Button({
	Title = "Clear",
	Desc = "Clear console.",
	Icon = "trash-2",
	Callback = function()
		table.clear(Logs)
		RefreshLogs()
	end,
})

LogsTab:Button({
	Title = "Copy",
	Desc = "Copy console.",
	Icon = "clipboard",
	Callback = function()
		local text = table.concat(Logs, "\n")

		pcall(function()
			if setclipboard then
				setclipboard(text)
			end
		end)

		WindUI:Notify({
			Title = "Kasane",
			Content = "Copied.",
			Icon = "clipboard-check",
			Duration = 2,
		})
	end,
})

-- =========================================================
-- SETTINGS
-- =========================================================

Settings:Section({ Title = "INTERFACE", TextSize = Mobile and 15 or 18 })

Settings:Keybind({
	Title = "Hub Key",
	Desc = "Toggle hub.",
	Value = "RightControl",
	Icon = "keyboard",
	Callback = function(value)
		local key

		if typeof(value) == "EnumItem" then
			key = value
		elseif type(value) == "string" then
			key = Enum.KeyCode[value]
		end

		if key then
			CONFIG.UI.Keybind = key

			pcall(function()
				Window:SetToggleKey(key)
			end)
		end
	end,
})

Settings:Toggle({
	Title = "Black Rose",
	Desc = "Kasane palette.",
	Icon = "palette",
	Value = true,
	Callback = function(value)
		pcall(function()
			WindUI:SetTheme(value and "Kasane" or "Dark")
		end)
	end,
})

Settings:Button({
	Title = "Reapply Theme",
	Desc = "Restore theme.",
	Icon = "paintbrush",
	Callback = function()
		pcall(function()
			WindUI:SetTheme("Kasane")
		end)
	end,
})

Settings:Section({ Title = "WINDOW", TextSize = Mobile and 15 or 18 })

if not Mobile then
	Settings:Input({
		Title = "Width",
		Desc = "Desktop width.",
		Value = tostring(CONFIG.UI.Width),
		Placeholder = "1080",
		InputIcon = "move-horizontal",
		Type = "Input",
		Callback = function(value)
			local number = tonumber(value)
			if number then
				CONFIG.UI.Width = math.clamp(number, 760, 1280)
				pcall(function()
					Window:SetSize(UDim2.fromOffset(CONFIG.UI.Width, CONFIG.UI.Height))
				end)
			end
		end,
	})

	Settings:Input({
		Title = "Height",
		Desc = "Desktop height.",
		Value = tostring(CONFIG.UI.Height),
		Placeholder = "620",
		InputIcon = "move-vertical",
		Type = "Input",
		Callback = function(value)
			local number = tonumber(value)
			if number then
				CONFIG.UI.Height = math.clamp(number, 440, 800)
				pcall(function()
					Window:SetSize(UDim2.fromOffset(CONFIG.UI.Width, CONFIG.UI.Height))
				end)
			end
		end,
	})
end

Settings:Button({
	Title = "Reset Window",
	Desc = "Restore default size.",
	Icon = "maximize",
	Callback = function()
		if Mobile then
			pcall(function()
				Window:SetUIScale(0.80)
				Window:SetSize(GetResponsiveSize())
			end)
		else
			CONFIG.UI.Width = 1080
			CONFIG.UI.Height = 620

			pcall(function()
				Window:SetUIScale(1)
				Window:SetSize(UDim2.fromOffset(1080, 620))
			end)
		end
	end,
})

Settings:Section({ Title = "SYSTEM", TextSize = Mobile and 15 or 18 })

Settings:Button({
	Title = "Refresh Touchline",
	Desc = "Re-resolve module.",
	Icon = "refresh-cw",
	Callback = function()
		RefreshTouchline()
		Log("Touchline refreshed.", "success")
	end,
})

Settings:Button({
	Title = "Restore TPS",
	Desc = "Restore football.",
	Icon = "rotate-ccw",
	Callback = function()
		ToggleTPSPhysical(false)
		Spatial:Toggle(false)
		Log("TPS restored.", "success")
	end,
})

Settings:Button({
	Title = "Destroy UI",
	Desc = "Remove Kasane.",
	Icon = "x",
	Callback = function()
		_G.KasaneCleanup()
	end,
})

Settings:Section({ Title = "ABOUT", TextSize = Mobile and 15 or 18 })

Settings:Paragraph({
	Title = "KASANE HUB",
	Desc = "Touchline x TPS\nWindUI / Black Rose\nv1.0.0",
	Image = "heart",
	ImageSize = 20,
	Color = C.Pink,
})

-- =========================================================
-- INIT
-- =========================================================

Engine.Mode = CONFIG.FFlags.Mode
Engine.Interval = CONFIG.FFlags.Interval

RefreshTouchline()

Log("Kasane initialized.", "success")
Log(Mobile and "Mobile layout." or "Desktop layout.", "info")

RefreshLogs()

pcall(function()
	Window:SetSize(GetResponsiveSize())

	if Mobile then
		local shortAxis = math.min(Viewport.X, Viewport.Y)

		Window:SetUIScale(
			shortAxis <= 430 and 0.76
			or shortAxis <= 600 and 0.80
			or 0.84
		)
	else
		Window:SetUIScale(1)
	end

	Window:SelectTab(1)
end)

WindUI:Notify({
	Title = "KASANE HUB",
	Content = "Initialized.",
	Icon = "sparkles",
	Duration = 3,
})
