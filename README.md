--[[
    SOUND ANTI DESYNC – Freeze other players
    Single‑button toggle, no spam, no extra fluff.
]]

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Global state (persist across script reloads)
connections = connections or {}
connections.FreezePlayer = connections.FreezePlayer or {}
featureStates = featureStates or {}
featureStates.FreezePlayer = false

-- ============================================================
--  FEATURE LOGIC – Freeze other players
-- ============================================================
local function toggleFreeze(enabled)
    if enabled then
        featureStates.FreezePlayer = true

        local conn = RunService.Stepped:Connect(function()
            if not featureStates.FreezePlayer then
                conn:Disconnect()
                return
            end

            local myChar = LocalPlayer.Character
            if not myChar then return end

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local char = plr.Character
                    if char then
                        -- Freeze humanoid
                        local hum = char:FindFirstChildWhichIsA("Humanoid")
                        if hum then
                            hum.WalkSpeed = 0
                            hum.JumpPower = 0
                            hum.AutoRotate = false
                        end

                        -- Disable collisions on all parts
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end
        end)

        table.insert(connections.FreezePlayer, conn)

    else
        featureStates.FreezePlayer = false

        -- Clean up connections
        for _, conn in ipairs(connections.FreezePlayer) do
            if conn then
                if typeof(conn) == "RBXScriptConnection" then
                    conn:Disconnect()
                elseif typeof(conn) == "thread" then
                    task.cancel(conn)
                end
            end
        end
        connections.FreezePlayer = {}

        -- Restore other players to default
        local DEFAULT_WALK = 16
        local DEFAULT_JUMP = 50
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                if char then
                    local hum = char:FindFirstChildWhichIsA("Humanoid")
                    if hum then
                        hum.WalkSpeed = DEFAULT_WALK
                        hum.JumpPower = DEFAULT_JUMP
                        hum.AutoRotate = true
                    end
                end
            end
        end
    end
end

-- ============================================================
--  GUI BUILDERS
-- ============================================================
local function getGuiParent()
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function newInstance(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local function addCorner(obj, radius)
    return newInstance("UICorner", { CornerRadius = UDim.new(0, radius) }, obj)
end

local function addStroke(obj, color, thickness, transparency)
    return newInstance("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end

-- ============================================================
--  BUILD THE GUI
-- ============================================================
local parent = getGuiParent()
local existing = parent:FindFirstChild("SoundAntiDesyncGui")
if existing then existing:Destroy() end

local gui = newInstance("ScreenGui", {
    Name = "SoundAntiDesyncGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Protect GUI (if executor supports it)
if type(syn) == "table" and type(syn.protect_gui) == "function" then
    pcall(syn.protect_gui, gui)
elseif typeof(protectgui) == "function" then
    pcall(protectgui, gui)
end

pcall(function() gui.Parent = parent end)
if not gui.Parent then
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Main container
local frame = newInstance("Frame", {
    Size = UDim2.fromOffset(230, 92),
    Position = UDim2.new(0.5, -115, 0.5, -46),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    ZIndex = 40,
}, gui)
addCorner(frame, 13)
addStroke(frame, Color3.fromRGB(90, 50, 140), 1.3)

-- Inner holder (image + overlay)
local holder = newInstance("Frame", {
    Size = UDim2.new(1, -6, 1, -6),
    Position = UDim2.fromOffset(3, 3),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 40,
}, frame)
addCorner(holder, 10)

-- Background image
newInstance("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = "rbxassetid://98596557474777",
    ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = 0.22,
    ZIndex = 40,
}, holder)

-- Dark overlay
newInstance("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(15, 5, 25),
    BackgroundTransparency = 0.74,
    BorderSizePixel = 0,
    ZIndex = 41,
}, holder)

-- Header
local header = newInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 31),
    BackgroundColor3 = Color3.fromRGB(10, 4, 18),
    BorderSizePixel = 0,
    ZIndex = 42,
}, holder)
newInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = Color3.fromRGB(90, 50, 140),
    BorderSizePixel = 0,
    ZIndex = 43,
}, header)
newInstance("TextLabel", {
    Size = UDim2.new(1, -76, 1, 0),
    Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1,
    Text = "SOUND ANTI DESYNC",
    TextColor3 = Color3.fromRGB(220, 180, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 43,
}, header)

-- Toggle button
local toggleBtn = newInstance("TextButton", {
    Size = UDim2.new(1, -18, 0, 39),
    Position = UDim2.fromOffset(9, 43),
    BackgroundColor3 = Color3.fromRGB(30, 15, 45),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "ACTIVATE",
    TextColor3 = Color3.fromRGB(180, 100, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    ZIndex = 42,
}, holder)
addCorner(toggleBtn, 10)

-- ============================================================
--  STATE & BUTTON BEHAVIOUR
-- ============================================================
local active = false

local function setActive(state)
    active = state
    if state then
        toggleBtn.Text = "DEACTIVATE"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(140, 50, 220)
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleFreeze(true)
    else
        toggleBtn.Text = "ACTIVATE"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 15, 45)
        toggleBtn.TextColor3 = Color3.fromRGB(180, 100, 255)
        toggleFreeze(false)
    end
end

toggleBtn.Activated:Connect(function()
    setActive(not active)
end)

-- Hover animations
toggleBtn.MouseEnter:Connect(function()
    local target = active and Color3.fromRGB(160, 70, 240) or Color3.fromRGB(45, 20, 65)
    TweenService:Create(toggleBtn, TweenInfo.new(0.12), { BackgroundColor3 = target }):Play()
end)
toggleBtn.MouseLeave:Connect(function()
    local target = active and Color3.fromRGB(140, 50, 220) or Color3.fromRGB(30, 15, 45)
    TweenService:Create(toggleBtn, TweenInfo.new(0.12), { BackgroundColor3 = target }):Play()
end)

-- ============================================================
--  DRAGGING (move the window)
-- ============================================================
local dragging = false
local dragStart, startPos

local function onInputBegan(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end

frame.InputBegan:Connect(onInputBegan)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                     input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Start with the feature off
setActive(false)

print("SOUND ANTI DESYNC loaded – click the button to freeze other players.")
