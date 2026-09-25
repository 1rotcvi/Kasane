--!nocheck
--[[
    AXIOM x KASANE HUB
    Touchline x TPS
    WindUI / Black Rose
    Reach engine attached
]]

local Services = {
    RunService   = game:GetService("RunService"),
    Players      = game:GetService("Players"),
    Lighting     = game:GetService("Lighting"),
    Workspace    = game:GetService("Workspace"),
    UserInput    = game:GetService("UserInputService"),
    HttpService  = game:GetService("HttpService"),
    RepStorage   = game:GetService("ReplicatedStorage"),
    TweenService = game:GetService("TweenService"),
    CoreGui      = game:GetService("CoreGui"),
}

local LocalPlayer = Services.Players.LocalPlayer

-- =========================================================
-- PALETTE
-- =========================================================
local COLORS = {
    Black       = Color3.fromHex("#050505"),
    Black2      = Color3.fromHex("#090909"),
    Black3      = Color3.fromHex("#0D0D0D"),
    Surface     = Color3.fromHex("#121212"),
    Surface2    = Color3.fromHex("#171717"),
    Surface3    = Color3.fromHex("#1C1C1C"),

    Pink        = Color3.fromHex("#C96891"),
    PinkSoft    = Color3.fromHex("#DA86A9"),
    PinkMuted   = Color3.fromHex("#B85B81"),
    PinkDark    = Color3.fromHex("#74364F"),
    PinkDeep    = Color3.fromHex("#351722"),

    Text        = Color3.fromHex("#F2F2F2"),
    Muted       = Color3.fromHex("#A7A7A7"),
    Dim         = Color3.fromHex("#666666"),

    Success     = Color3.fromHex("#74C99A"),
    Warning     = Color3.fromHex("#D9B66F"),
    Error       = Color3.fromHex("#D36F83"),
}

-- =========================================================
-- CONFIG
-- =========================================================
local CONFIG = {
    Touchline = {
        Enabled = true,
        SmartGK = true,
        SizeX = 4, SizeY = 7, SizeZ = 3,
        GkSizeX = 5, GkSizeY = 5.25, GkSizeZ = 2,
    },
    TPS = {
        PhysicalEnabled = false,
        PhysicalSize = 5,
        Transparency = 0.45,
        SpatialEnabled = false,
        Radius = 15,
        TickRate = 0.05,
    },
    Flags = { Interval = 1 },
    UI = {
        Name = "AXIOM x KASANE",
        Version = "1.0.0",
        Keybind = Enum.KeyCode.RightControl,
        Width = 1050,
        Height = 600,
        Theme = "AxiomBlackRose",
    },
}

-- =========================================================
-- LIFECYCLE
-- =========================================================
if _G.AxiomCleanup then pcall(_G.AxiomCleanup) end

local ActiveConnections = {}
local ActiveThreads = {}

local function TrackConnection(connection)
    if typeof(connection) == "RBXScriptConnection" then
        ActiveConnections[#ActiveConnections + 1] = connection
    end
    return connection
end

local function TrackThread(thread)
    if thread then ActiveThreads[#ActiveThreads + 1] = thread end
    return thread
end

_G.AxiomCleanup = function()
    for _, connection in ipairs(ActiveConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(ActiveConnections)

    for _, thread in ipairs(ActiveThreads) do
        pcall(function() task.cancel(thread) end)
    end
    table.clear(ActiveThreads)

    if type(_G.AxiomClearTPS) == "function" then pcall(_G.AxiomClearTPS) end

    if _G.AxiomUnifiedEngine and type(_G.AxiomUnifiedEngine.Stop) == "function" then
        pcall(function() _G.AxiomUnifiedEngine:Stop() end)
    end

    if _G.AxiomLauncherGui and typeof(_G.AxiomLauncherGui) == "Instance" then
        pcall(function() _G.AxiomLauncherGui:Destroy() end)
    end

    if _G.AxiomWindWindow and type(_G.AxiomWindWindow) == "table" then
        pcall(function()
            if type(_G.AxiomWindWindow.Destroy) == "function" then
                _G.AxiomWindWindow:Destroy()
            end
        end)
    end
end

local function GetGuiParent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end
    return Services.CoreGui
end

local function IsMobile()
    return Services.UserInput.TouchEnabled and not Services.UserInput.KeyboardEnabled
end

-- =========================================================
-- WINDUI
-- =========================================================
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

pcall(function()
    WindUI:AddTheme({
        Name = "AxiomBlackRose",
        Accent = COLORS.Pink,
        Background = COLORS.Black,
        Outline = COLORS.PinkDark,
        Text = COLORS.Text,
        Placeholder = COLORS.Muted,
        Button = COLORS.Surface,
        Icon = COLORS.PinkSoft,
    })
    WindUI:SetTheme("AxiomBlackRose")
end)

-- =========================================================
-- TOUCHLINE ENGINE
-- =========================================================
local Touchline = {
    Module = nil,
    Detect = nil,
    UpvalueIndex = nil,
    OriginalSize = Vector3.new(2.25, 5.25, 1.5),
    OriginalGetPartBoundsInBox = nil,
    Hooked = false,
}

local function resolveTouchModule()
    Touchline.Module = nil
    Touchline.Detect = nil
    Touchline.UpvalueIndex = nil

    pcall(function()
        local modules = Services.RepStorage:FindFirstChild("Modules")
        local touch = modules and modules:FindFirstChild("Touch")
        if touch and touch:IsA("ModuleScript") then
            local ok, result = pcall(require, touch)
            if ok and type(result) == "table" and type(result.Detect) == "function" then
                Touchline.Module = result
                Touchline.Detect = result.Detect
            end
        end
    end)

    if not Touchline.Detect and type(getgc) == "function" then
        pcall(function()
            for _, value in pairs(getgc(true)) do
                if type(value) == "function" then
                    local ok, info = pcall(debug.getinfo, value)
                    if ok and type(info) == "table" and info.name == "Detect" then
                        Touchline.Detect = value
                        break
                    end
                end
            end
        end)
    end

    if Touchline.Detect and type(debug.getupvalue) == "function" then
        for index = 1, 30 do
            local ok, _, value = pcall(debug.getupvalue, Touchline.Detect, index)
            if ok and typeof(value) == "Vector3" then
                Touchline.UpvalueIndex = index
                Touchline.OriginalSize = value
                break
            end
        end
    end
end

local function isGoalie()
    local result = false
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local main = playerGui and playerGui:FindFirstChild("Main")
        local values = main and main:FindFirstChild("Values")
        local goalie = values and values:FindFirstChild("Goalie")
        if goalie then result = goalie.Value end
    end)
    return result
end

local function getTouchlineVector()
    if CONFIG.Touchline.SmartGK and isGoalie() then
        return Vector3.new(
            tonumber(CONFIG.Touchline.GkSizeX) or 5,
            tonumber(CONFIG.Touchline.GkSizeY) or 5.25,
            tonumber(CONFIG.Touchline.GkSizeZ) or 2
        )
    end
    return Vector3.new(
        tonumber(CONFIG.Touchline.SizeX) or 4,
        tonumber(CONFIG.Touchline.SizeY) or 7,
        tonumber(CONFIG.Touchline.SizeZ) or 3
    )
end

local function updateTouchlineUpvalue()
    if not Touchline.Detect or not Touchline.UpvalueIndex then return end
    if type(debug.setupvalue) ~= "function" then return end

    local targetSize
    if CONFIG.Touchline.Enabled then
        targetSize = getTouchlineVector()
    else
        targetSize = Touchline.OriginalSize
    end

    pcall(debug.setupvalue, Touchline.Detect, Touchline.UpvalueIndex, targetSize)
end

local function installWorkspaceHook()
    if Touchline.Hooked then return end

    if typeof(hookfunction) == "function" then
        local ok = pcall(function()
            Touchline.OriginalGetPartBoundsInBox = hookfunction(
                Services.Workspace.GetPartBoundsInBox,
                function(self, cframe, size, params)
                    local internal = type(checkcaller) == "function" and checkcaller() or false
                    if CONFIG.Touchline.Enabled and not internal then
                        return Touchline.OriginalGetPartBoundsInBox(
                            self, cframe, getTouchlineVector(), params
                        )
                    end
                    return Touchline.OriginalGetPartBoundsInBox(self, cframe, size, params)
                end
            )
        end)
        if ok then Touchline.Hooked = true end
    end

    if not Touchline.Hooked and typeof(hookmetamethod) == "function" then
        local oldNamecall
        local ok = pcall(function()
            oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if self == Services.Workspace
                    and (method == "GetPartBoundsInBox" or method == "getPartBoundsInBox") then
                    local internal = type(checkcaller) == "function" and checkcaller() or false
                    if CONFIG.Touchline.Enabled and not internal then
                        local args = table.pack(...)
                        args[2] = getTouchlineVector()
                        return oldNamecall(self, table.unpack(args, 1, args.n))
                    end
                end
                return oldNamecall(self, ...)
            end))
        end)
        if ok then Touchline.Hooked = true end
    end
end

local function hookTouchline()
    resolveTouchModule()
    installWorkspaceHook()
    updateTouchlineUpvalue()
end

hookTouchline()

TrackConnection(Services.RunService.Stepped:Connect(function()
    updateTouchlineUpvalue()
end))

TrackConnection(Services.UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F3 then
        CONFIG.Touchline.Enabled = not CONFIG.Touchline.Enabled
        updateTouchlineUpvalue()
    end
end))

-- =========================================================
-- TPS PHYSICAL
-- =========================================================
local TPSConnections = {}

local function getFootballs()
    local folder = Services.Workspace:FindFirstChild("Footballs")
    local balls = {}
    if folder then
        for _, object in ipairs(folder:GetChildren()) do
            if object:IsA("BasePart") then balls[#balls + 1] = object end
        end
    end
    return balls
end

local function applyTPSPhysical(ball)
    if not ball or not ball.Parent or not ball:IsA("BasePart") then return end

    if not ball:FindFirstChild("AxiomTPSOriginal") then
        local marker = Instance.new("Folder")
        marker.Name = "AxiomTPSOriginal"
        marker:SetAttribute("Size", ball.Size)
        marker:SetAttribute("Transparency", ball.Transparency)
        marker:SetAttribute("CanCollide", ball.CanCollide)
        marker.Parent = ball
    end

    if CONFIG.TPS.PhysicalEnabled then
        local size = tonumber(CONFIG.TPS.PhysicalSize) or 5
        ball.Size = Vector3.new(size, size, size)
        ball.Transparency = CONFIG.TPS.Transparency
        ball.CanCollide = false

        if not ball:FindFirstChild("AxiomTPSVisual") then
            local visual = Instance.new("SelectionBox")
            visual.Name = "AxiomTPSVisual"
            visual.Adornee = ball
            visual.LineThickness = 0.035
            visual.Color3 = COLORS.Pink
            visual.SurfaceTransparency = 1
            visual.Parent = ball
        end
    end
end

local function clearTPSPhysical()
    for _, ball in ipairs(getFootballs()) do
        local marker = ball:FindFirstChild("AxiomTPSOriginal")
        if marker then
            local size = marker:GetAttribute("Size")
            local transparency = marker:GetAttribute("Transparency")
            local canCollide = marker:GetAttribute("CanCollide")

            if typeof(size) == "Vector3" then ball.Size = size end
            if typeof(transparency) == "number" then ball.Transparency = transparency end
            if typeof(canCollide) == "boolean" then ball.CanCollide = canCollide end

            local visual = ball:FindFirstChild("AxiomTPSVisual")
            if visual then pcall(function() visual:Destroy() end) end
            pcall(function() marker:Destroy() end)
        end
    end
end

_G.AxiomClearTPS = clearTPSPhysical

local function toggleTPSPhysical(state)
    CONFIG.TPS.PhysicalEnabled = state

    for _, connection in ipairs(TPSConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(TPSConnections)

    if state then
        for _, ball in ipairs(getFootballs()) do applyTPSPhysical(ball) end
        local folder = Services.Workspace:FindFirstChild("Footballs")
        if folder then
            local connection = folder.ChildAdded:Connect(function(object)
                if object:IsA("BasePart") then
                    task.wait()
                    applyTPSPhysical(object)
                end
            end)
            TPSConnections[#TPSConnections + 1] = connection
            TrackConnection(connection)
        end
    else
        clearTPSPhysical()
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
    local pref = Services.Lighting:FindFirstChild(LocalPlayer.Name)
    local isRight = not pref
        or not pref:FindFirstChild("PreferredFoot")
        or pref.PreferredFoot.Value == 1

    local footName
    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        footName = isRight and "Right Leg" or "Left Leg"
    else
        footName = isRight and "RightLowerLeg" or "LeftLowerLeg"
    end

    return character:FindFirstChild(footName)
end

function Spatial:Tick()
    local now = os.clock()
    if now - self.LastTick < CONFIG.TPS.TickRate then return end
    self.LastTick = now

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and humanoid.Health > 0 and root) then return end

    local system = Services.Workspace:FindFirstChild("TPSSystem")
    local ball = system and system:FindFirstChild("TPS")
    if not ball then return end

    self.Overlap.FilterDescendantsInstances = { ball }
    local hits = Services.Workspace:GetPartBoundsInRadius(root.Position, CONFIG.TPS.Radius, self.Overlap)

    if #hits > 0 then
        local foot = self:GetFoot(character, humanoid)
        if foot and type(firetouchinterest) == "function" then
            pcall(function()
                firetouchinterest(foot, ball, 0)
                firetouchinterest(foot, ball, 1)
            end)
        end
    end
end

function Spatial:Toggle(state)
    CONFIG.TPS.SpatialEnabled = state
    if state and not self.Connection then
        self.Connection = TrackConnection(Services.RunService.Heartbeat:Connect(function() self:Tick() end))
    elseif not state and self.Connection then
        pcall(function() self.Connection:Disconnect() end)
        self.Connection = nil
    end
end

-- =========================================================
-- FFLAG ENGINE
-- =========================================================
local FlagEngine = {}
FlagEngine.__index = FlagEngine

local FLAG_PREFIXES = { "^DFInt", "^DFFlag", "^DFlag", "^FFlag", "^FInt", "^DFint" }
local FLAG_BLOCKLIST = { "FString", "FFString", "FLog" }

function FlagEngine.new(config)
    config = config or {}
    return setmetatable({
        Running = false,
        Worker = nil,
        Mode = "Once",
        Queue = {},
        Interval = math.max(0.05, tonumber(config.Interval) or 1),
    }, FlagEngine)
end

function FlagEngine:_normalizeName(name)
    local result = tostring(name)
    for _, prefix in ipairs(FLAG_PREFIXES) do
        result = result:gsub(prefix, "")
    end
    return result
end

function FlagEngine:Parse(jsonText)
    if type(jsonText) ~= "string" or jsonText == "" then
        return false, "JSON input is empty", 0
    end

    local decoded
    local ok = pcall(function()
        decoded = Services.HttpService:JSONDecode(jsonText)
    end)

    if not ok or type(decoded) ~= "table" then
        return false, "Invalid JSON format", 0
    end

    local parsed, rejected = {}, 0

    for name, value in pairs(decoded) do
        local key = tostring(name)
        local denied = false

        for _, blocked in ipairs(FLAG_BLOCKLIST) do
            if key:find(blocked, 1, true) then denied = true; break end
        end

        if denied then
            rejected += 1
        else
            table.insert(parsed, {
                OriginalName = key,
                CleanName = self:_normalizeName(key),
                Target = tostring(value),
            })
        end
    end

    if #parsed == 0 then return false, "No valid flags to queue", rejected end
    return true, parsed, rejected
end

function FlagEngine:QueueFlags(flags)
    table.clear(self.Queue)
    for _, flag in ipairs(flags) do
        table.insert(self.Queue, {
            OriginalName = flag.OriginalName,
            CleanName = flag.CleanName,
            Target = flag.Target,
        })
    end
end

function FlagEngine:ClearQueue() table.clear(self.Queue) end
function FlagEngine:GetQueue() return self.Queue end

function FlagEngine:Start(onLog)
    if self.Running or self.Worker then return false end
    if #self.Queue == 0 then
        if type(onLog) == "function" then
            pcall(onLog, "error", "Cannot start: Queue is empty.")
        end
        return false
    end

    self.Running = true
    if type(onLog) == "function" then
        pcall(onLog, "info", string.format("Engine started (Interval: %s)", self.Interval))
    end

    self.Worker = task.spawn(function()
        while self.Running do
            for _, flag in ipairs(self.Queue) do
                if not self.Running then break end

                local success = pcall(function()
                    setfflag(flag.CleanName, flag.Target)
                end)

                if type(onLog) == "function" then
                    if success then
                        pcall(onLog, "call_ok", string.format("%s = %s", flag.OriginalName, flag.Target))
                    else
                        pcall(onLog, "error", "Failed: " .. flag.OriginalName)
                    end
                end
            end

            if self.Mode == "Once" then
                if type(onLog) == "function" then pcall(onLog, "info", "Applied once.") end
                self.Running = false
                break
            end

            task.wait(math.max(0.05, tonumber(self.Interval) or 1))
        end
        self.Worker = nil
        self.Running = false
    end)

    TrackThread(self.Worker)
    return true
end

function FlagEngine:Stop()
    self.Running = false
    if self.Worker then
        pcall(task.cancel, self.Worker)
        self.Worker = nil
    end
end

local Engine = FlagEngine.new({ Interval = CONFIG.Flags.Interval })
_G.AxiomUnifiedEngine = Engine

-- =========================================================
-- LOG SYSTEM
-- =========================================================
local LogHistory = {}
local LogsParagraph

local function renderLogs()
    if not LogsParagraph then return end

    local total = #LogHistory
    local from = math.max(1, total - 49)
    local lines = {}

    for index = from, total do
        table.insert(lines, LogHistory[index])
    end

    local text = #lines > 0 and table.concat(lines, "\n") or "No entries."
    pcall(function() LogsParagraph:SetDesc(text) end)
end

local function logFlag(message, state)
    local stateName = string.lower(state or "info")
    local prefix =
        stateName == "call_ok" and "[OK]" or
        stateName == "error" and "[ERR]" or
        stateName == "warn" and "[WARN]" or
        "[INFO]"

    local entry = string.format("[%s] %s %s", os.date("%H:%M:%S"), prefix, tostring(message))
    table.insert(LogHistory, entry)

    if #LogHistory > 300 then table.remove(LogHistory, 1) end
    renderLogs()
end

-- =========================================================
-- WINDOW
-- =========================================================
local function GetViewport()
    local camera = Services.Workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function GetWindowSize()
    local viewport = GetViewport()
    if IsMobile() then
        return UDim2.fromOffset(
            math.clamp(viewport.X - 30, 760, 1100),
            math.clamp(viewport.Y - 80, 440, 700)
        )
    end
    return UDim2.fromOffset(CONFIG.UI.Width, CONFIG.UI.Height)
end

local Window = WindUI:CreateWindow({
    Title = CONFIG.UI.Name,
    Icon = "sparkles",
    Author = "Touchline x TPS",
    Folder = "AxiomKasaneHub",
    Size = GetWindowSize(),
    MinSize = Vector2.new(740, 440),
    MaxSize = Vector2.new(1250, 780),
    Resizable = true,
    SideBarWidth = 205,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    NewElements = true,
    OpenButton = { Enabled = false },
    Topbar = { Height = 46, ButtonsType = "Mac" },
})

_G.AxiomWindWindow = Window

pcall(function()
    Window:Tag({ Title = "AXIOM", Icon = "sparkles", Color = COLORS.PinkDeep, Border = true })
    Window:Tag({ Title = "ONLINE", Icon = "activity", Color = COLORS.Black3, Border = true })
    Window:Tag({ Title = CONFIG.UI.Version, Icon = "badge", Color = COLORS.Black3, Border = true })
end)

-- =========================================================
-- CUSTOM LAUNCHER
-- =========================================================
local function CreateLauncher()
    if _G.AxiomLauncherGui and typeof(_G.AxiomLauncherGui) == "Instance" then
        pcall(function() _G.AxiomLauncherGui:Destroy() end)
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AxiomLauncher"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = GetGuiParent()
    _G.AxiomLauncherGui = gui

    local button = Instance.new("TextButton")
    button.Name = "Launcher"
    button.AnchorPoint = Vector2.new(0.5, 0)
    button.Position = IsMobile()
        and UDim2.new(1, -12, 0, 12)
        or UDim2.new(0.5, 0, 0, 18)
    button.Size = IsMobile()
        and UDim2.fromOffset(60, 46)
        or UDim2.fromOffset(172, 42)
    button.BackgroundColor3 = COLORS.Black
    button.BackgroundTransparency = 0.02
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = ""
    button.ZIndex = 100
    button.Parent = gui

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.Black2),
        ColorSequenceKeypoint.new(0.5, COLORS.Black3),
        ColorSequenceKeypoint.new(1, COLORS.PinkDeep),
    })
    gradient.Rotation = 90
    gradient.Parent = button

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.PinkMuted
    stroke.Thickness = 1.35
    stroke.Transparency = 0.12
    stroke.Parent = button

    local icon = Instance.new("TextLabel")
    icon.BackgroundTransparency = 1
    icon.Position = IsMobile() and UDim2.fromOffset(16, 0) or UDim2.fromOffset(13, 0)
    icon.Size = UDim2.fromOffset(28, 42)
    icon.Text = "✦"
    icon.TextColor3 = COLORS.PinkSoft
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 19
    icon.ZIndex = 101
    icon.Parent = button

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(44, 0)
    title.Size = UDim2.fromOffset(84, 42)
    title.Text = "AXIOM"
    title.TextColor3 = COLORS.Text
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Visible = not IsMobile()
    title.ZIndex = 101
    title.Parent = button

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(7, 7)
    dot.Position = UDim2.fromOffset(128, 18)
    dot.BackgroundColor3 = COLORS.PinkSoft
    dot.BorderSizePixel = 0
    dot.Visible = not IsMobile()
    dot.ZIndex = 101
    dot.Parent = button

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    local right = Instance.new("TextLabel")
    right.BackgroundTransparency = 1
    right.Position = UDim2.fromOffset(142, 0)
    right.Size = UDim2.fromOffset(20, 42)
    right.Text = "›"
    right.TextColor3 = COLORS.Muted
    right.Font = Enum.Font.GothamMedium
    right.TextSize = 20
    right.Visible = not IsMobile()
    right.ZIndex = 101
    right.Parent = button

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = button

    local function Animate(value)
        Services.TweenService:Create(
            scale,
            TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Scale = value }
        ):Play()
    end

    TrackConnection(button.MouseEnter:Connect(function()
        if IsMobile() then return end
        Animate(1.04)
        Services.TweenService:Create(stroke, TweenInfo.new(0.14), { Transparency = 0 }):Play()
        Services.TweenService:Create(dot, TweenInfo.new(0.14), { BackgroundColor3 = COLORS.Pink }):Play()
    end))

    TrackConnection(button.MouseLeave:Connect(function()
        if IsMobile() then return end
        Animate(1)
        Services.TweenService:Create(stroke, TweenInfo.new(0.14), { Transparency = 0.12 }):Play()
        Services.TweenService:Create(dot, TweenInfo.new(0.14), { BackgroundColor3 = COLORS.PinkSoft }):Play()
    end))

    local dragging, moved = false, false
    local dragInput, dragStart, startPosition

    TrackConnection(button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            moved = false
            dragStart = input.Position
            startPosition = button.Position
        end
    end))

    TrackConnection(button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end))

    TrackConnection(Services.UserInput.InputChanged:Connect(function(input)
        if not dragging or input ~= dragInput then return end
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then moved = true end
        button.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end))

    TrackConnection(button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    TrackConnection(button.Activated:Connect(function()
        if moved then return end
        pcall(function() Window:Toggle() end)
    end))
end

CreateLauncher()

-- =========================================================
-- RESPONSIVE RESIZE
-- =========================================================
TrackConnection(Services.RunService.RenderStepped:Connect(function()
    if not IsMobile() then return end
    local camera = Services.Workspace.CurrentCamera
    if not camera then return end

    local viewport = camera.ViewportSize
    local width = math.clamp(viewport.X - 30, 760, 1100)
    local height = math.clamp(viewport.Y - 80, 440, 700)

    pcall(function()
        Window:SetSize(UDim2.fromOffset(width, height))
    end)
end))

-- =========================================================
-- SECTIONS
-- =========================================================
local Sections = {
    Core = Window:Section({ Title = "CORE", Opened = true }),
    Tools = Window:Section({ Title = "TOOLS", Opened = true }),
    System = Window:Section({ Title = "SYSTEM", Opened = true }),
}

-- =========================================================
-- TABS
-- =========================================================
local Tabs = {
    Home      = Sections.Core:Tab({ Title = "Home",      Icon = "house" }),
    Touchline = Sections.Core:Tab({ Title = "Touchline", Icon = "crosshair" }),
    TPS       = Sections.Core:Tab({ Title = "TPS",       Icon = "circle-dot" }),
    FFlags    = Sections.Core:Tab({ Title = "FFlags",    Icon = "flag" }),
    Presets   = Sections.Tools:Tab({ Title = "Presets",  Icon = "bookmark" }),
    Logs      = Sections.Tools:Tab({ Title = "Logs",     Icon = "terminal" }),
    Settings  = Sections.System:Tab({ Title = "Settings", Icon = "settings" }),
}

-- =========================================================
-- HOME
-- =========================================================
Tabs.Home:Paragraph({
    Title = "AXIOM x KASANE",
    Desc = "Touchline x TPS\nBlack Rose interface",
    Image = "sparkles",
    ImageSize = 22,
    Color = COLORS.Pink,
})

Tabs.Home:Divider()

local EngineStatus = Tabs.Home:Paragraph({
    Title = "Engine", Desc = "Ready",
    Image = "cpu", ImageSize = 19, Color = COLORS.Pink,
})

local TouchStatus = Tabs.Home:Paragraph({
    Title = "Touchline",
    Desc = CONFIG.Touchline.Enabled and "Enabled" or "Disabled",
    Image = "crosshair", ImageSize = 19, Color = COLORS.Pink,
})

local TPSStatus = Tabs.Home:Paragraph({
    Title = "TPS",
    Desc = "Physical: " .. tostring(CONFIG.TPS.PhysicalEnabled) .. "\nSpatial: " .. tostring(CONFIG.TPS.SpatialEnabled),
    Image = "circle-dot", ImageSize = 19, Color = COLORS.Pink,
})

local function refreshTPSStatus()
    pcall(function()
        TPSStatus:SetDesc(
            "Physical: " .. tostring(CONFIG.TPS.PhysicalEnabled) ..
            "\nSpatial: " .. tostring(CONFIG.TPS.SpatialEnabled)
        )
    end)
end

Tabs.Home:Section({ Title = "QUICK CONTROL", TextSize = 18 })

Tabs.Home:Toggle({
    Title = "Touchline Reach",
    Desc = "Enable Touchline reach.",
    Icon = "crosshair",
    Value = CONFIG.Touchline.Enabled,
    Callback = function(value)
        CONFIG.Touchline.Enabled = value
        updateTouchlineUpvalue()
        TouchStatus:SetDesc(value and "Enabled" or "Disabled")
    end,
})

Tabs.Home:Toggle({
    Title = "Smart GK",
    Desc = "Auto-adapt for goalkeeper.",
    Icon = "goal",
    Value = CONFIG.Touchline.SmartGK,
    Callback = function(value)
        CONFIG.Touchline.SmartGK = value
        updateTouchlineUpvalue()
    end,
})

Tabs.Home:Toggle({
    Title = "TPS Physical",
    Desc = "Enable physical ball reach.",
    Icon = "circle-dot",
    Value = CONFIG.TPS.PhysicalEnabled,
    Callback = function(value)
        toggleTPSPhysical(value)
        refreshTPSStatus()
    end,
})

Tabs.Home:Toggle({
    Title = "TPS Spatial",
    Desc = "Enable spatial touch.",
    Icon = "radio",
    Value = CONFIG.TPS.SpatialEnabled,
    Callback = function(value)
        Spatial:Toggle(value)
        refreshTPSStatus()
    end,
})

Tabs.Home:Button({
    Title = "Refresh Everything",
    Desc = "Re-hook Touchline + TPS.",
    Icon = "refresh-cw",
    Callback = function()
        hookTouchline()
        toggleTPSPhysical(CONFIG.TPS.PhysicalEnabled)
        Spatial:Toggle(CONFIG.TPS.SpatialEnabled)
        logFlag("Full refresh executed.", "info")
        WindUI:Notify({ Title = "Axiom", Content = "Systems refreshed.", Icon = "check", Duration = 2 })
    end,
})

-- =========================================================
-- TOUCHLINE
-- =========================================================
Tabs.Touchline:Section({ Title = "SMART DETECT", TextSize = 18 })

Tabs.Touchline:Toggle({
    Title = "Enable Touchline Reach",
    Desc = "Custom detection dimensions.",
    Icon = "crosshair",
    Value = CONFIG.Touchline.Enabled,
    Callback = function(value)
        CONFIG.Touchline.Enabled = value
        updateTouchlineUpvalue()
        TouchStatus:SetDesc(value and "Enabled" or "Disabled")
    end,
})

Tabs.Touchline:Toggle({
    Title = "Smart GK Auto-Adapt",
    Desc = "Auto-adapt for goalkeeper.",
    Icon = "goal",
    Value = CONFIG.Touchline.SmartGK,
    Callback = function(value)
        CONFIG.Touchline.SmartGK = value
        updateTouchlineUpvalue()
    end,
})

Tabs.Touchline:Section({ Title = "PLAYER XYZ", TextSize = 18 })

Tabs.Touchline:Slider({
    Title = "Size X", Desc = "Player X dimension.",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = CONFIG.Touchline.SizeX },
    Callback = function(value)
        CONFIG.Touchline.SizeX = value
        updateTouchlineUpvalue()
    end,
})

Tabs.Touchline:Slider({
    Title = "Size Y", Desc = "Player Y dimension.",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = CONFIG.Touchline.SizeY },
    Callback = function(value)
        CONFIG.Touchline.SizeY = value
        updateTouchlineUpvalue()
    end,
})

Tabs.Touchline:Slider({
    Title = "Size Z", Desc = "Player Z dimension.",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = CONFIG.Touchline.SizeZ },
    Callback = function(value)
        CONFIG.Touchline.SizeZ = value
        updateTouchlineUpvalue()
    end,
})

Tabs.Touchline:Section({ Title = "GOALKEEPER XYZ", TextSize = 18 })

Tabs.Touchline:Slider({
    Title = "GK Size X", Desc = "Goalkeeper X.",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = CONFIG.Touchline.GkSizeX },
    Callback = function(value)
        CONFIG.Touchline.GkSizeX = value
        updateTouchlineUpvalue()
    end,
})

Tabs.Touchline:Slider({
    Title = "GK Size Y", Desc = "Goalkeeper Y.",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = CONFIG.Touchline.GkSizeY },
    Callback = function(value)
        CONFIG.Touchline.GkSizeY = value
        updateTouchlineUpvalue()
    end,
})

Tabs.Touchline:Slider({
    Title = "GK Size Z", Desc = "Goalkeeper Z.",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = CONFIG.Touchline.GkSizeZ },
    Callback = function(value)
        CONFIG.Touchline.GkSizeZ = value
        updateTouchlineUpvalue()
    end,
})

Tabs.Touchline:Button({
    Title = "Re-Hook Module",
    Desc = "Refresh Touch module detection.",
    Icon = "refresh-cw",
    Callback = function()
        hookTouchline()
        logFlag("Touch module re-hooked.", "call_ok")
        WindUI:Notify({ Title = "Touchline", Content = "Re-hooked.", Icon = "check", Duration = 2 })
    end,
})

-- =========================================================
-- TPS
-- =========================================================
Tabs.TPS:Section({ Title = "PHYSICAL REACH", TextSize = 18 })

Tabs.TPS:Toggle({
    Title = "Enable Physical Reach",
    Desc = "Resize football objects.",
    Icon = "maximize-2",
    Value = CONFIG.TPS.PhysicalEnabled,
    Callback = function(value)
        toggleTPSPhysical(value)
        refreshTPSStatus()
    end,
})

Tabs.TPS:Slider({
    Title = "Hitbox Size", Desc = "Physical ball size.",
    Step = 1,
    Value = { Min = 1, Max = 30, Default = CONFIG.TPS.PhysicalSize },
    Callback = function(value)
        CONFIG.TPS.PhysicalSize = value
        if CONFIG.TPS.PhysicalEnabled then toggleTPSPhysical(true) end
    end,
})

Tabs.TPS:Section({ Title = "SPATIAL", TextSize = 18 })

Tabs.TPS:Toggle({
    Title = "Enable Spatial Touch",
    Desc = "Spatial touch scan.",
    Icon = "radio",
    Value = CONFIG.TPS.SpatialEnabled,
    Callback = function(value)
        Spatial:Toggle(value)
        refreshTPSStatus()
    end,
})

Tabs.TPS:Slider({
    Title = "Spatial Radius", Desc = "Spatial scan radius.",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = CONFIG.TPS.Radius },
    Callback = function(value) CONFIG.TPS.Radius = value end,
})

Tabs.TPS:Slider({
    Title = "Tick Rate", Desc = "Spatial update rate.",
    Step = 0.01,
    Value = { Min = 0.01, Max = 0.5, Default = CONFIG.TPS.TickRate },
    Callback = function(value)
        CONFIG.TPS.TickRate = math.max(0.01, value)
    end,
})

-- =========================================================
-- FFLAGS
-- =========================================================
local cachedJson = '{"DFIntTargetTimeDelayFacctorTenths":"7"}'

Tabs.FFlags:Section({ Title = "JSON INJECTOR", TextSize = 18 })

Tabs.FFlags:Input({
    Title = "Flag JSON",
    Desc = "Paste JSON flags here.",
    InputIcon = "braces",
    Type = "Textarea",
    Value = cachedJson,
    Callback = function(value) cachedJson = value end,
})

Tabs.FFlags:Toggle({
    Title = "Loop Mode",
    Desc = "Repeat the queue continuously.",
    Icon = "repeat",
    Value = false,
    Callback = function(value)
        Engine.Mode = value and "Loop" or "Once"
    end,
})

Tabs.FFlags:Slider({
    Title = "Flag Interval", Desc = "Loop interval.",
    Step = 1,
    Value = { Min = 1, Max = 10, Default = CONFIG.Flags.Interval },
    Callback = function(value)
        CONFIG.Flags.Interval = value
        Engine.Interval = value
    end,
})

Tabs.FFlags:Section({ Title = "ACTIONS", TextSize = 18 })

Tabs.FFlags:Button({
    Title = "Parse Flags",
    Desc = "Validate JSON and queue flags.",
    Icon = "scan",
    Callback = function()
        logFlag("Parsing JSON...", "info")
        local ok, parsed, rejected = Engine:Parse(cachedJson)
        if not ok then
            logFlag(tostring(parsed), "error")
            WindUI:Notify({ Title = "Parser", Content = tostring(parsed), Icon = "x", Duration = 3 })
            return
        end
        Engine:QueueFlags(parsed)
        logFlag(string.format("Valid: %d | Rejected: %d", #parsed, rejected), "info")
        WindUI:Notify({ Title = "Parser", Content = string.format("%d flags queued.", #parsed), Icon = "check", Duration = 2 })
    end,
})

Tabs.FFlags:Button({
    Title = "Start Inject",
    Desc = "Start the flag worker.",
    Icon = "play",
    Callback = function()
        local started = Engine:Start(function(state, message)
            logFlag(message, state)
        end)
        if started then
            EngineStatus:SetDesc("Running • " .. Engine.Mode)
        end
    end,
})

Tabs.FFlags:Button({
    Title = "Stop Inject",
    Desc = "Stop the flag worker.",
    Icon = "square",
    Callback = function()
        Engine:Stop()
        EngineStatus:SetDesc("Stopped")
        logFlag("Worker stopped.", "info")
    end,
})

Tabs.FFlags:Button({
    Title = "Clear Queue",
    Desc = "Clear queued flags.",
    Icon = "trash-2",
    Callback = function()
        Engine:ClearQueue()
        logFlag("Queue cleared.", "info")
    end,
})

-- =========================================================
-- PRESETS
-- =========================================================
local PRESETS = {
    ["Default (4/7/3)"]    = { X=4, Y=7, Z=3, GKX=5, GKY=5.25, GKZ=2, Ball=5, Radius=15, Tick=0.05 },
    ["Compact (3/5/2)"]    = { X=3, Y=5, Z=2, GKX=4, GKY=5,    GKZ=2, Ball=4, Radius=10, Tick=0.05 },
    ["Extended (6/9/5)"]   = { X=6, Y=9, Z=5, GKX=6, GKY=7,    GKZ=4, Ball=8, Radius=25, Tick=0.01 },
    ["Aggressive (8/12/6)"]= { X=8, Y=12, Z=6, GKX=8, GKY=9,   GKZ=5, Ball=10, Radius=35, Tick=0.01 },
}

local PresetNames = {}
for name in pairs(PRESETS) do PresetNames[#PresetNames + 1] = name end
table.sort(PresetNames)

Tabs.Presets:Section({ Title = "REACH PROFILES", TextSize = 18 })

Tabs.Presets:Dropdown({
    Title = "Reach Profile",
    Desc = "Choose a preset.",
    Values = PresetNames,
    Value = PresetNames[1],
    AllowNone = false,
    Callback = function(name)
        local p = PRESETS[name]
        if not p then return end
        CONFIG.Touchline.SizeX   = p.X
        CONFIG.Touchline.SizeY   = p.Y
        CONFIG.Touchline.SizeZ   = p.Z
        CONFIG.Touchline.GkSizeX = p.GKX
        CONFIG.Touchline.GkSizeY = p.GKY
        CONFIG.Touchline.GkSizeZ = p.GKZ
        CONFIG.TPS.PhysicalSize  = p.Ball
        CONFIG.TPS.Radius        = p.Radius
        CONFIG.TPS.TickRate      = p.Tick
        updateTouchlineUpvalue()
        if CONFIG.TPS.PhysicalEnabled then toggleTPSPhysical(true) end
        logFlag("Loaded reach: " .. name, "info")
        WindUI:Notify({ Title = "Presets", Content = "Loaded " .. name, Icon = "bookmark-check", Duration = 2 })
    end,
})

Tabs.Presets:Section({ Title = "FFLAG PRESETS", TextSize = 18 })

local FLAG_PRESETS = {
    ["Interp Low (35ms)"]   = '{"FIntInterpolationMaxDelayMSec":"35"}',
    ["Interp Mid (60ms)"]   = '{"FIntInterpolationMaxDelayMSec":"60"}',
    ["Interp High (120ms)"] = '{"FIntInterpolationMaxDelayMSec":"120"}',
    ["Target Time Delay 7"] = '{"DFIntTargetTimeDelayFacctorTenths":"7"}',
    ["Target Time Delay 10"]= '{"DFIntTargetTimeDelayFacctorTenths":"10"}',
    ["Custom Empty"]        = '{}',
}

local FlagPresetNames = {}
for name in pairs(FLAG_PRESETS) do FlagPresetNames[#FlagPresetNames + 1] = name end
table.sort(FlagPresetNames)

Tabs.Presets:Dropdown({
    Title = "Flag Preset",
    Desc = "Load a FFlag JSON into the injector.",
    Values = FlagPresetNames,
    Value = FlagPresetNames[1],
    AllowNone = false,
    Callback = function(selected)
        local preset = FLAG_PRESETS[selected]
        if not preset then return end
        cachedJson = preset
        logFlag("Loaded flag preset: " .. selected, "info")
        WindUI:Notify({ Title = "FFlag Preset", Content = selected, Icon = "bookmark-check", Duration = 2 })
    end,
})

Tabs.Presets:Button({
    Title = "Apply Flag Preset Now",
    Desc = "Parse + Start Once with current JSON.",
    Icon = "zap",
    Callback = function()
        local ok, parsed = Engine:Parse(cachedJson)
        if not ok then
            logFlag(tostring(parsed), "error")
            return
        end
        Engine:QueueFlags(parsed)
        Engine.Mode = "Once"
        Engine:Start(function(state, message) logFlag(message, state) end)
    end,
})

-- =========================================================
-- LOGS
-- =========================================================
Tabs.Logs:Section({ Title = "EXECUTION LOG", TextSize = 18 })

LogsParagraph = Tabs.Logs:Paragraph({
    Title = "Axiom Console",
    Desc = "No entries.",
    Image = "terminal",
    ImageSize = 20,
    Color = COLORS.Pink,
})

Tabs.Logs:Button({
    Title = "Clear Logs",
    Desc = "Clear execution history.",
    Icon = "trash-2",
    Callback = function()
        table.clear(LogHistory)
        renderLogs()
        logFlag("Log cleared.", "info")
    end,
})

Tabs.Logs:Button({
    Title = "Copy Log",
    Desc = "Copy execution history.",
    Icon = "clipboard",
    Callback = function()
        local text = table.concat(LogHistory, "\n")
        pcall(function()
            if setclipboard then setclipboard(text) end
        end)
        WindUI:Notify({ Title = "Logs", Content = "Copied.", Icon = "clipboard-check", Duration = 2 })
    end,
})

-- =========================================================
-- SETTINGS
-- =========================================================
Tabs.Settings:Section({ Title = "INTERFACE", TextSize = 18 })

Tabs.Settings:Keybind({
    Title = "Hub Keybind",
    Desc = "Toggle the UI.",
    Value = "RightControl",
    Icon = "keyboard",
    Callback = function(value)
        local keyName = tostring(value):gsub("Enum.KeyCode.", "")
        local key = Enum.KeyCode[keyName]
        if key then
            CONFIG.UI.Keybind = key
            pcall(function() Window:SetToggleKey(key) end)
        end
    end,
})

Tabs.Settings:Toggle({
    Title = "Black Rose",
    Desc = "Custom black/pink theme.",
    Icon = "palette",
    Value = true,
    Callback = function(value)
        pcall(function()
            WindUI:SetTheme(value and "AxiomBlackRose" or "Dark")
        end)
    end,
})

Tabs.Settings:Button({
    Title = "Reapply Theme",
    Desc = "Restore Black Rose colors.",
    Icon = "paintbrush",
    Callback = function()
        pcall(function() WindUI:SetTheme("AxiomBlackRose") end)
        WindUI:Notify({ Title = "Axiom", Content = "Black Rose applied.", Icon = "heart", Duration = 2 })
    end,
})

Tabs.Settings:Section({ Title = "WINDOW", TextSize = 18 })

Tabs.Settings:Slider({
    Title = "Window Width", Desc = "Desktop width.",
    Step = 10,
    Value = { Min = 760, Max = 1200, Default = CONFIG.UI.Width },
    Callback = function(value)
        CONFIG.UI.Width = value
        if not IsMobile() then
            pcall(function()
                Window:SetSize(UDim2.fromOffset(CONFIG.UI.Width, CONFIG.UI.Height))
            end)
        end
    end,
})

Tabs.Settings:Slider({
    Title = "Window Height", Desc = "Desktop height.",
    Step = 10,
    Value = { Min = 440, Max = 760, Default = CONFIG.UI.Height },
    Callback = function(value)
        CONFIG.UI.Height = value
        if not IsMobile() then
            pcall(function()
                Window:SetSize(UDim2.fromOffset(CONFIG.UI.Width, CONFIG.UI.Height))
            end)
        end
    end,
})

Tabs.Settings:Button({
    Title = "Reset Window",
    Desc = "Restore default dimensions.",
    Icon = "maximize",
    Callback = function()
        CONFIG.UI.Width = 1050
        CONFIG.UI.Height = 600
        pcall(function()
            Window:SetSize(UDim2.fromOffset(CONFIG.UI.Width, CONFIG.UI.Height))
        end)
    end,
})

Tabs.Settings:Button({
    Title = "Rebuild Launcher",
    Desc = "Recreate the floating button.",
    Icon = "refresh-cw",
    Callback = function() CreateLauncher() end,
})

-- =========================================================
-- ABOUT
-- =========================================================
Tabs.Settings:Section({ Title = "ABOUT", TextSize = 18 })

Tabs.Settings:Paragraph({
    Title = "AXIOM x KASANE",
    Desc = "Touchline x TPS\nWindUI / Black Rose\nVersion " .. CONFIG.UI.Version,
    Image = "heart",
    ImageSize = 22,
    Color = COLORS.Pink,
})

Tabs.Settings:Button({
    Title = "Re-Hook Everything",
    Desc = "Refresh Touchline, TPS, and hooks.",
    Icon = "refresh-cw",
    Callback = function()
        hookTouchline()
        toggleTPSPhysical(CONFIG.TPS.PhysicalEnabled)
        Spatial:Toggle(CONFIG.TPS.SpatialEnabled)
        logFlag("All modules refreshed.", "info")
    end,
})

-- =========================================================
-- INITIAL STATE
-- =========================================================
pcall(function() WindUI:SetTheme("AxiomBlackRose") end)
pcall(function() Window:SetToggleKey(CONFIG.UI.Keybind) end)
pcall(function() Window:SelectTab(1) end)

logFlag("Axiom x Kasane Hub loaded.", "call_ok")
logFlag("Reach engine attached.", "info")
logFlag("Black Rose interface active.", "info")
renderLogs()

WindUI:Notify({
    Title = "AXIOM x KASANE",
    Content = "Interface initialized.",
    SubContent = "Reach engine attached",
    Icon = "sparkles",
    Duration = 4,
})

print("[AXIOM x KASANE] Hub loaded.")
