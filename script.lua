-- ==========================================
-- SOUND HUB V3.5 - DELTA EXECUTOR FIXED + VISUALS TAB
-- ==========================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==========================================
-- AUTO STEAL & RADIUS CONFIGURATION
-- ==========================================
local autoStealEnabled = false
local autoStealRadius = 8
local STEAL_DURATION = 1.3
local isStealing = false
local StealData = {}

-- ==========================================
-- ANTI-DESYNC & COUNTERS LOGIC CONFIGURATION
-- ==========================================
local antiDesyncEnabled = false
local antiDesyncAutoSwingEnabled = true
local batCounterEnabled = false
local batCounterDebounce = false
local BAT_SLAP_LIST = {"Bat", "BaseballBat", "SlapBat"}
local medCounterEnabled = false
local noPlayerCollisionEnabled = false
local antiDieEnabled = false

-- ==========================================
-- KEYBINDS CONFIGURATION MAP
-- ==========================================
local KeybindsData = {
    ["nrml spd"] = Enum.KeyCode.One,
    ["lagger spd"] = Enum.KeyCode.Two,
    ["extra spd"] = Enum.KeyCode.Three,
    ["tp down"] = Enum.KeyCode.Q,
    ["dropt br"] = Enum.KeyCode.E,
    ["auto left"] = Enum.KeyCode.Z,
    ["auto right"] = Enum.KeyCode.C,
    ["anti desync"] = Enum.KeyCode.V,
    ["gui"] = Enum.KeyCode.RightControl
}

local extButtonsMap = {}

-- ==========================================
-- NO PLAYER COLLISION LOGIC IMPLEMENTATION
-- ==========================================
local function updateNoCollision()
    local character = LocalPlayer.Character
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not noPlayerCollisionEnabled
        end
    end
end

RunService.Stepped:Connect(function()
    if noPlayerCollisionEnabled then
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if noPlayerCollisionEnabled then
        updateNoCollision()
    end
end)

-- ==========================================
-- MED COUNTER LOGIC IMPLEMENTATION
-- ==========================================
local function findMedForCounter(character)
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():find("med") or tool.Name:lower():find("kit") or tool.Name:lower():find("bandage")) then
            return tool
        end
    end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:lower():find("med") or tool.Name:lower():find("kit") or tool.Name:lower():find("bandage")) then
                return tool
            end
        end
    end
    return nil
end

local function useMedForCounter(character, med)
    if med.Parent ~= character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:EquipTool(med) end
    end
    local remoteEvent = med:FindFirstChild("RemoteEvent") or med:FindFirstChild("UseEvent") or med:FindFirstChild("HitEvent")
    task.spawn(function()
        for i = 1, 2 do
            if remoteEvent and remoteEvent:IsA("RemoteEvent") then
                remoteEvent:FireServer()
            else
                med:Activate()
            end
            task.wait(0.15)
        end
    end)
end

RunService.Heartbeat:Connect(function()
    if not medCounterEnabled then return end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if humanoid.Health < (humanoid.MaxHealth * 0.6) then
        local med = findMedForCounter(character)
        if med then useMedForCounter(character, med) end
    end
end)

local AceAntiDesync = { conn = nil, hittingCooldown = false, h = nil, hrp = nil }

-- ==========================================
-- BAT COUNTER LOGIC IMPLEMENTATION
-- ==========================================
local function findBatForCounter(character)
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            for _, batName in ipairs(BAT_SLAP_LIST) do
                if tool.Name == batName then return tool end
            end
        end
    end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                for _, batName in ipairs(BAT_SLAP_LIST) do
                    if tool.Name == batName then return tool end
                end
            end
        end
    end
    return nil
end

local function swingBatForCounter(character, bat)
    if bat.Parent ~= character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:EquipTool(bat) end
    end
    local remoteEvent = bat:FindFirstChild("RemoteEvent") or bat:FindFirstChild("HitEvent")
    task.spawn(function()
        for i = 1, 2 do
            if remoteEvent and remoteEvent:IsA("RemoteEvent") then
                remoteEvent:FireServer()
            else
                bat:Activate()
            end
            task.wait(0.15)
        end
    end)
end

RunService.Heartbeat:Connect(function()
    if not batCounterEnabled or batCounterDebounce then return end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local currentState = humanoid:GetState()
    if currentState == Enum.HumanoidStateType.Physics or currentState == Enum.HumanoidStateType.Ragdoll or currentState == Enum.HumanoidStateType.FallingDown then
        batCounterDebounce = true
        task.spawn(function()
            local bat = findBatForCounter(character)
            if bat then swingBatForCounter(character, bat) end
            task.wait(0.5)
            batCounterDebounce = false
        end)
    end
end)

-- ==========================================
-- ANTI DIE LOGIC IMPLEMENTATION
-- ==========================================
local antiDieConnections = {}
local originalHumanoidStates = {}

local function toggleAntiDie(active)
    antiDieEnabled = active
    if active then
        if antiDieConnections.FreezePlayer then antiDieConnections.FreezePlayer:Disconnect() end
        antiDieConnections.FreezePlayer = RunService.Stepped:Connect(function()
            if not antiDieEnabled then
                if antiDieConnections.FreezePlayer then
                    antiDieConnections.FreezePlayer:Disconnect()
                    antiDieConnections.FreezePlayer = nil
                end
                return
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local char = plr.Character
                    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        if not originalHumanoidStates[plr] then
                            originalHumanoidStates[plr] = {
                                WalkSpeed = humanoid.WalkSpeed,
                                JumpPower = humanoid.JumpPower,
                                AutoRotate = humanoid.AutoRotate
                            }
                        end
                        humanoid.WalkSpeed = 0
                        humanoid.JumpPower = 0
                        humanoid.AutoRotate = false
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    end
                end
            end
        end)
    else
        if antiDieConnections.FreezePlayer then
            antiDieConnections.FreezePlayer:Disconnect()
            antiDieConnections.FreezePlayer = nil
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                local humanoid = plr.Character:FindFirstChildWhichIsA("Humanoid")
                local defaults = originalHumanoidStates[plr]
                if humanoid and defaults then
                    humanoid.WalkSpeed = defaults.WalkSpeed
                    humanoid.JumpPower = defaults.JumpPower
                    humanoid.AutoRotate = defaults.AutoRotate
                end
            end
        end
        originalHumanoidStates = {}
    end
end

local function getBat()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChild("Bat")
    if tool then return tool end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        tool = bp:FindFirstChild("Bat")
        if tool then
            tool.Parent = char
            return tool
        end
    end
    return nil
end

local function trySwing()
    if AceAntiDesync.hittingCooldown then return end
    AceAntiDesync.hittingCooldown = true
    pcall(function()
        local bat = getBat()
        if bat then
            bat:Activate()
            local ev = bat:FindFirstChildWhichIsA("RemoteEvent")
            if ev then ev:FireServer() end
        end
    end)
    task.delay(0.08, function() AceAntiDesync.hittingCooldown = false end)
end

local function getClosestAntiDesyncPlayer()
    local hrp = AceAntiDesync.hrp
    if not hrp then return nil, math.huge end
    local closest, minDist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local d = (hrp.Position - tr.Position).Magnitude
                if d < minDist then minDist = d; closest = p end
            end
        end
    end
    return closest, minDist
end

local function setupAntiDesyncChar(char)
    task.wait(0.1)
    AceAntiDesync.h = char and char:WaitForChild("Humanoid", 5) or nil
    AceAntiDesync.hrp = char and char:WaitForChild("HumanoidRootPart", 5) or nil
end

local function startAntiDesyncAimbot()
    if antiDesyncEnabled then return end
    antiDesyncEnabled = true
    if AceAntiDesync.conn then AceAntiDesync.conn:Disconnect(); AceAntiDesync.conn = nil end
    if LocalPlayer.Character then pcall(function() setupAntiDesyncChar(LocalPlayer.Character) end) end
    AceAntiDesync.conn = RunService.Heartbeat:Connect(function()
        if not antiDesyncEnabled or not AceAntiDesync.h or not AceAntiDesync.hrp then return end
        local target, _ = getClosestAntiDesyncPlayer()
        if target and target.Character then
            local tr = target.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local targetPos = tr.Position + Vector3.new(0, 0.9, 0)
                if (AceAntiDesync.hrp.Position - targetPos).Magnitude > 8 then
                    AceAntiDesync.hrp.CFrame = CFrame.new(targetPos)
                end
                local cam = workspace.CurrentCamera
                if cam then cam.CFrame = CFrame.new(cam.CFrame.Position, tr.Position) end
                if antiDesyncAutoSwingEnabled then trySwing() end
            end
        end
    end)
end

local function stopAntiDesyncAimbot()
    antiDesyncEnabled = false
    if AceAntiDesync.conn then AceAntiDesync.conn:Disconnect(); AceAntiDesync.conn = nil end
    AceAntiDesync.hittingCooldown = false
end

LocalPlayer.CharacterAdded:Connect(function(char) pcall(function() setupAntiDesyncChar(char) end) end)
if LocalPlayer.Character then task.spawn(function() setupAntiDesyncChar(LocalPlayer.Character) end) end

-- ==========================================
-- DROP BR LOGIC CONFIGURATION
-- ==========================================
local DROP_ASCEND_SPEED = 150
local DROP_ASCEND_DURATION = 0.2
local dropActive = false

-- ==========================================
-- INTRO ANIMATION & SOUND SETUP
-- ==========================================
local SoundHubIntro = Instance.new("ScreenGui")
SoundHubIntro.Name = "SoundHubAdvancedIntro"
SoundHubIntro.IgnoreGuiInset = true
SoundHubIntro.ResetOnSpawn = false
SoundHubIntro.DisplayOrder = 9999

local successIntro, errIntro = pcall(function() SoundHubIntro.Parent = game:GetService("CoreGui") end)
if not successIntro then SoundHubIntro.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local introBlur = Instance.new("BlurEffect")
introBlur.Size = 25
introBlur.Parent = Lighting

local introSound = Instance.new("Sound")
introSound.SoundId = "rbxassetid://9069176008"
introSound.Volume = 3.0
introSound.Parent = SoundHubIntro
introSound:Play()

local MainContainer = Instance.new("Frame")
MainContainer.Name = "MainContainer"
MainContainer.Size = UDim2.new(1, 0, 1, 0)
MainContainer.BackgroundTransparency = 1
MainContainer.Parent = SoundHubIntro

local BackgroundFrame = Instance.new("Frame")
BackgroundFrame.Size = UDim2.new(1.1, 0, 1.1, 0)
BackgroundFrame.Position = UDim2.new(-0.05, 0, -0.05, 0)
BackgroundFrame.BackgroundColor3 = Color3.fromRGB(2, 2, 4)
BackgroundFrame.BorderSizePixel = 0
BackgroundFrame.Parent = MainContainer

for i = 1, 10 do
    local gridLine = Instance.new("Frame")
    gridLine.Size = UDim2.new(1, 0, 0, 1)
    gridLine.Position = UDim2.new(0, 0, i * 0.1, 0)
    gridLine.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    gridLine.BackgroundTransparency = 0.85
    gridLine.BorderSizePixel = 0
    gridLine.Parent = BackgroundFrame
end

local function createTechCorner(pos, anchor)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(0, 30, 0, 30)
    c.Position = pos
    c.AnchorPoint = anchor
    c.BackgroundTransparency = 1
    c.Parent = MainContainer
    local s1 = Instance.new("Frame")
    s1.Size = UDim2.new(1, 0, 0, 2)
    s1.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    s1.BorderSizePixel = 0
    s1.Parent = c
    local s2 = Instance.new("Frame")
    s2.Size = UDim2.new(0, 2, 1, 0)
    s2.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    s2.BorderSizePixel = 0
    s2.Parent = c
end
createTechCorner(UDim2.new(0, 20, 0, 20), Vector2.new(0,0))
createTechCorner(UDim2.new(1, -20, 0, 20), Vector2.new(1,0))
createTechCorner(UDim2.new(0, 20, 1, -20), Vector2.new(0,1))
createTechCorner(UDim2.new(1, -20, 1, -20), Vector2.new(1,1))

local TerminalBox = Instance.new("TextLabel")
TerminalBox.Size = UDim2.new(0, 400, 0, 100)
TerminalBox.Position = UDim2.new(0.5, -200, 0, 45)
TerminalBox.BackgroundTransparency = 1
TerminalBox.Text = ""
TerminalBox.TextColor3 = Color3.fromRGB(168, 85, 247)
TerminalBox.TextSize = 10
TerminalBox.Font = Enum.Font.Code
TerminalBox.TextXAlignment = Enum.TextXAlignment.Left
TerminalBox.TextYAlignment = Enum.TextYAlignment.Top
TerminalBox.Parent = MainContainer

local BabydollLyricsText = Instance.new("TextLabel")
BabydollLyricsText.ZIndex = 8
BabydollLyricsText.AnchorPoint = Vector2.new(0.5, 0.5)
BabydollLyricsText.Position = UDim2.new(0.5, 0, 0.28, 0)
BabydollLyricsText.Size = UDim2.new(0, 600, 0, 40)
BabydollLyricsText.BackgroundTransparency = 1
BabydollLyricsText.Text = "♪ Oh, Father, forgive me, for all my sins... ♪"
BabydollLyricsText.TextColor3 = Color3.fromRGB(255, 120, 180)
BabydollLyricsText.TextSize = 15
BabydollLyricsText.Font = Enum.Font.GothamBold
BabydollLyricsText.TextTransparency = 1
BabydollLyricsText.Parent = MainContainer

local LogoContainer = Instance.new("Frame")
LogoContainer.ZIndex = 5
LogoContainer.AnchorPoint = Vector2.new(0.5, 0.5)
LogoContainer.Position = UDim2.new(0.5, 0, 0.45, 0)
LogoContainer.Size = UDim2.new(0, 75, 0, 75)
LogoContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
LogoContainer.Parent = MainContainer

local LogoStroke = Instance.new("UIStroke")
LogoStroke.Color = Color3.fromRGB(168, 85, 247)
LogoStroke.Transparency = 0.2
LogoStroke.Thickness = 2
LogoStroke.Parent = LogoContainer

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 12)
LogoCorner.Parent = LogoContainer

local SkullEmoji = Instance.new("TextLabel")
SkullEmoji.ZIndex = 6
SkullEmoji.Size = UDim2.new(1, 0, 1, 0)
SkullEmoji.BackgroundTransparency = 1
SkullEmoji.Text = "💀"
SkullEmoji.TextSize = 35
SkullEmoji.Font = Enum.Font.GothamBold
SkullEmoji.Parent = LogoContainer

local SoundTextFrame = Instance.new("Frame")
SoundTextFrame.Position = UDim2.new(0, 0, 0.56, 0)
SoundTextFrame.Size = UDim2.new(1, 0, 0, 50)
SoundTextFrame.BackgroundTransparency = 1
SoundTextFrame.Parent = MainContainer

local SoundLayout = Instance.new("UIListLayout")
SoundLayout.Padding = UDim.new(0, 6)
SoundLayout.FillDirection = Enum.FillDirection.Horizontal
SoundLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SoundLayout.VerticalAlignment = Enum.VerticalAlignment.Center
SoundLayout.Parent = SoundTextFrame

local HubTextFrame = Instance.new("Frame")
HubTextFrame.Position = UDim2.new(0, 0, 0.64, 0)
HubTextFrame.Size = UDim2.new(1, 0, 0, 50)
HubTextFrame.BackgroundTransparency = 1
HubTextFrame.Parent = MainContainer

local HubLayout = Instance.new("UIListLayout")
HubLayout.Padding = UDim.new(0, 8)
HubLayout.FillDirection = Enum.FillDirection.Horizontal
HubLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
HubLayout.VerticalAlignment = Enum.VerticalAlignment.Center
HubLayout.Parent = HubTextFrame

local createdLetterLabels = {}
for _, char in ipairs({"S", "O", "U", "N", "D"}) do
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 34, 0, 48)
    label.BackgroundTransparency = 1
    label.Text = char
    label.TextColor3 = Color3.fromRGB(168, 85, 247)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextTransparency = 1
    label.Parent = SoundTextFrame
    table.insert(createdLetterLabels, label)
end

for _, char in ipairs({"H", "U", "B"}) do
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 38, 0, 48)
    label.BackgroundTransparency = 1
    label.Text = char
    label.TextColor3 = Color3.fromRGB(240, 240, 240)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextTransparency = 1
    label.Parent = HubTextFrame
    table.insert(createdLetterLabels, label)
end

local ProgressBarBg = Instance.new("Frame")
ProgressBarBg.AnchorPoint = Vector2.new(0.5, 0.5)
ProgressBarBg.Position = UDim2.new(0.5, 0, 0.77, 0)
ProgressBarBg.Size = UDim2.new(0, 360, 0, 6)
ProgressBarBg.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
ProgressBarBg.Parent = MainContainer

local ProgressBgCorner = Instance.new("UICorner")
ProgressBgCorner.CornerRadius = UDim.new(1, 0)
ProgressBgCorner.Parent = ProgressBarBg

local ProgressBarFill = Instance.new("Frame")
ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
ProgressBarFill.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
ProgressBarFill.Parent = ProgressBarBg

local ProgressFillCorner = Instance.new("UICorner")
ProgressFillCorner.CornerRadius = UDim.new(1, 0)
ProgressFillCorner.Parent = ProgressBarFill

local PercentageLabel = Instance.new("TextLabel")
PercentageLabel.AnchorPoint = Vector2.new(0.5, 0)
PercentageLabel.Position = UDim2.new(0.5, 0, 0.80, 0)
PercentageLabel.Size = UDim2.new(0, 200, 0, 30)
PercentageLabel.BackgroundTransparency = 1
PercentageLabel.Text = "SYSTEM INITIALIZING... [0%]"
PercentageLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
PercentageLabel.TextSize = 11
PercentageLabel.Font = Enum.Font.Code
PercentageLabel.Parent = MainContainer

task.spawn(function()
    local logs = {
        "> Loading core security modules...",
        "> Bypassing client environment checks...",
        "> Injecting SoundHub UI Framework v3.5...",
        "> Syncing user data: " .. LocalPlayer.Name,
        "> Establishing secure connection to discord.gg/HCxUsWKJte",
        "> Ready."
    }
    for _, log in ipairs(logs) do
        TerminalBox.Text = TerminalBox.Text .. "\n" .. log
        task.wait(0.25)
    end
end)

task.spawn(function()
    TweenService:Create(BabydollLyricsText, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
    task.wait(1.8)
    TweenService:Create(BabydollLyricsText, TweenInfo.new(0.6), {TextTransparency = 1}):Play()
end)

local isShaking = true
task.spawn(function()
    while isShaking do
        local offsetX = math.random(-3, 3)
        local offsetY = math.random(-3, 3)
        LogoContainer.Position = UDim2.new(0.5, offsetX, 0.45, offsetY)
        RunService.RenderStepped:Wait()
    end
    LogoContainer.Position = UDim2.new(0.5, 0, 0.45, 0)
end)

task.spawn(function()
    task.wait(0.6)
    for _, lbl in ipairs(createdLetterLabels) do
        TweenService:Create(lbl, TweenInfo.new(0.15), {TextTransparency = 0}):Play()
        task.wait(0.04)
    end
end)

local progress = 0
while progress < 100 do
    progress = progress + 1
    ProgressBarFill.Size = UDim2.new(progress / 100, 0, 1, 0)
    PercentageLabel.Text = "SYSTEM INITIALIZING... [" .. progress .. "%]"
    task.wait(0.025)
end

task.wait(0.3)
isShaking = false

local fadeOutInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(MainContainer, fadeOutInfo, {Size = UDim2.new(1.15, 0, 1.15, 0)}):Play()
TweenService:Create(introBlur, fadeOutInfo, {Size = 0}):Play()

for _, child in ipairs(MainContainer:GetDescendants()) do
    if child:IsA("TextLabel") then TweenService:Create(child, fadeOutInfo, {TextTransparency = 1}):Play()
    elseif child:IsA("Frame") then TweenService:Create(child, fadeOutInfo, {BackgroundTransparency = 1}):Play()
    elseif child:IsA("UIStroke") then TweenService:Create(child, fadeOutInfo, {Transparency = 1}):Play() end
end

task.wait(0.55)
SoundHubIntro:Destroy()
introBlur:Destroy()

-- ==========================================
-- 1. Create Main Container (ScreenGui)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SoundHubGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local success, err = pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(screenGui); screenGui.Parent = game:GetService("CoreGui")
    elseif gethui then screenGui.Parent = gethui()
    else screenGui.Parent = game:GetService("CoreGui") end
end)

if not success or not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ==========================================
-- 2. Create Top-Left Toggle Button
-- ==========================================
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "SoundHubToggleButton"
toggleButton.Size = UDim2.new(0, 75, 0, 22)
toggleButton.Position = UDim2.new(0, 10, 0, 40)
toggleButton.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
toggleButton.Text = "SOUND HUB"
toggleButton.TextColor3 = Color3.fromRGB(168, 85, 247)
toggleButton.TextSize = 9
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Active = true
toggleButton.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 5)
toggleCorner.Parent = toggleButton

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(168, 85, 247)
toggleStroke.Transparency = 0.5
toggleStroke.Thickness = 1
toggleStroke.Parent = toggleButton

-- ==========================================
-- 3. Create Main Window
-- ==========================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(168, 85, 247)
mainStroke.Transparency = 0.4
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

local headerFrame = Instance.new("Frame")
headerFrame.Name = "HeaderFrame"
headerFrame.Size = UDim2.new(1, -16, 0, 32)
headerFrame.Position = UDim2.new(0, 8, 0, 8)
headerFrame.BackgroundTransparency = 1
headerFrame.Parent = mainFrame

local logoBox = Instance.new("Frame")
logoBox.Name = "LogoBox"
logoBox.Size = UDim2.new(0, 24, 0, 24)
logoBox.Position = UDim2.new(0, 0, 0, 0)
logoBox.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
logoBox.Parent = headerFrame

local logoCorner = Instance.new("UICorner")
logoCorner.CornerRadius = UDim.new(0, 5)
logoCorner.Parent = logoBox

local logoStroke = Instance.new("UIStroke")
logoStroke.Color = Color3.fromRGB(168, 85, 247)
logoStroke.Transparency = 0.5
logoStroke.Thickness = 1
logoStroke.Parent = logoBox

local logoIcon = Instance.new("TextLabel")
logoIcon.Size = UDim2.new(1, 0, 1, 0)
logoIcon.BackgroundTransparency = 1
logoIcon.Text = "🎧"
logoIcon.TextColor3 = Color3.fromRGB(168, 85, 247)
logoIcon.TextSize = 11
logoIcon.Font = Enum.Font.GothamBold
logoIcon.Parent = logoBox

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0, 110, 0, 13)
titleLabel.Position = UDim2.new(0, 30, 0, -2)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SOUND HUB"
titleLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
titleLabel.TextSize = 10
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = headerFrame

local subTitleLabel = Instance.new("TextLabel")
subTitleLabel.Name = "SubTitleLabel"
subTitleLabel.Size = UDim2.new(0, 150, 0, 12)
subTitleLabel.Position = UDim2.new(0, 30, 0, 12)
subTitleLabel.BackgroundTransparency = 1
subTitleLabel.Text = "discord.gg/HCxUsWKJte"
subTitleLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
subTitleLabel.TextSize = 7
subTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subTitleLabel.Font = Enum.Font.Gotham
subTitleLabel.Parent = headerFrame

local lockToggleButton = Instance.new("TextButton")
lockToggleButton.Name = "LockToggleButton"
lockToggleButton.Size = UDim2.new(0, 32, 0, 18)
lockToggleButton.Position = UDim2.new(1, -36, 0, 3)
lockToggleButton.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
lockToggleButton.Text = "LOCK"
lockToggleButton.TextColor3 = Color3.fromRGB(255, 100, 100)
lockToggleButton.TextSize = 7
lockToggleButton.Font = Enum.Font.GothamBold
lockToggleButton.Parent = headerFrame

local lockCorner = Instance.new("UICorner")
lockCorner.CornerRadius = UDim.new(0, 4)
lockCorner.Parent = lockToggleButton

local lockStroke = Instance.new("UIStroke")
lockStroke.Color = Color3.fromRGB(168, 85, 247)
lockStroke.Transparency = 0.5
lockStroke.Thickness = 1
lockStroke.Parent = lockToggleButton

-- ==========================================
-- 4. Tabs Row
-- ==========================================
local tabsContainer = Instance.new("ScrollingFrame")
tabsContainer.Name = "TabsContainer"
tabsContainer.Size = UDim2.new(1, -16, 0, 22)
tabsContainer.Position = UDim2.new(0, 8, 0, 44)
tabsContainer.BackgroundTransparency = 1
tabsContainer.BorderSizePixel = 0
tabsContainer.CanvasSize = UDim2.new(0, 350, 0, 22)
tabsContainer.ScrollBarThickness = 0
tabsContainer.Parent = mainFrame

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Padding = UDim.new(0, 3)
tabsLayout.Parent = tabsContainer

local tabPages = {}

local function createTabButton(tabName, isDefault)
    local tabButton = Instance.new("TextButton")
    tabButton.Name = tabName .. "TabButton"
    tabButton.Size = UDim2.new(0, 52, 0, 20)
    tabButton.BackgroundColor3 = isDefault and Color3.fromRGB(16, 16, 16) or Color3.fromRGB(10, 10, 10)
    tabButton.Text = tabName
    tabButton.TextColor3 = isDefault and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(130, 130, 130)
    tabButton.TextSize = 8
    tabButton.Font = Enum.Font.GothamBold
    tabButton.Parent = tabsContainer

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 4)
    tabCorner.Parent = tabButton

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Color = isDefault and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(30, 30, 30)
    tabStroke.Transparency = isDefault and 0.4 or 0
    tabStroke.Thickness = 1
    tabStroke.Parent = tabButton

    local tabPage = Instance.new("ScrollingFrame")
    tabPage.Name = tabName .. "Page"
    tabPage.Size = UDim2.new(1, -16, 1, -74)
    tabPage.Position = UDim2.new(0, 8, 0, 70)
    tabPage.BackgroundTransparency = 1
    tabPage.BorderSizePixel = 0
    tabPage.ScrollBarThickness = 2
    tabPage.ScrollBarImageColor3 = Color3.fromRGB(168, 85, 247)
    tabPage.Visible = isDefault
    tabPage.Parent = mainFrame

    local pageList = Instance.new("UIListLayout")
    pageList.SortOrder = Enum.SortOrder.LayoutOrder
    pageList.Padding = UDim.new(0, 4)
    pageList.Parent = tabPage

    pageList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabPage.CanvasSize = UDim2.new(0, 0, 0, pageList.AbsoluteContentSize.Y + 5)
    end)

    tabPages[tabName] = {Button = tabButton, Stroke = tabStroke, Page = tabPage}

    tabButton.MouseButton1Click:Connect(function()
        for n, d in pairs(tabPages) do
            d.Page.Visible = false
            d.Button.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
            d.Button.TextColor3 = Color3.fromRGB(130, 130, 130)
            d.Stroke.Color = Color3.fromRGB(30, 30, 30)
            d.Stroke.Transparency = 0
        end
        tabPage.Visible = true
        tabButton.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
        tabButton.TextColor3 = Color3.fromRGB(168, 85, 247)
        tabStroke.Color = Color3.fromRGB(168, 85, 247)
        tabStroke.Transparency = 0.4
    end)

    return tabPage
end

local speedPage = createTabButton("MOVEMENT", true)
local combatPage = createTabButton("COMBAT", false)
local keybindsPage = createTabButton("KEYBINDS", false)
local visualsPage = createTabButton("VISUALS", false)
local settingsPage = createTabButton("SETTINGS", false)

-- ==========================================
-- BUILD KEYBINDS PAGE UI
-- ==========================================
local function createKeybindRow(featureName, defaultKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    row.Parent = keybindsPage

    local rCorner = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0, 4)
    rCorner.Parent = row

    local rStroke = Instance.new("UIStroke")
    rStroke.Color = Color3.fromRGB(30, 30, 30)
    rStroke.Thickness = 1
    rStroke.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = featureName:upper()
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 8
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 20, 0, 18)
    clearBtn.Position = UDim2.new(1, -54, 0.5, -9)
    clearBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    clearBtn.Text = "x"
    clearBtn.TextColor3 = Color3.fromRGB(168, 85, 247)
    clearBtn.TextSize = 8
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.Parent = row

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 3)
    cbCorner.Parent = clearBtn

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(0, 28, 0, 18)
    keyBtn.Position = UDim2.new(1, -30, 0.5, -9)
    keyBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    keyBtn.Text = defaultKey and defaultKey.Name or "None"
    keyBtn.TextColor3 = Color3.fromRGB(168, 85, 247)
    keyBtn.TextSize = 7.5
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.Parent = row

    local kbCorner = Instance.new("UICorner")
    kbCorner.CornerRadius = UDim.new(0, 3)
    kbCorner.Parent = keyBtn

    local listening = false
    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "..."
    end)

    clearBtn.MouseButton1Click:Connect(function()
        KeybindsData[featureName] = nil
        keyBtn.Text = "None"
        listening = false
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                KeybindsData[featureName] = input.KeyCode
                keyBtn.Text = input.KeyCode.Name
                listening = false
            end
        end
    end)
end

for name, kcode in pairs(KeybindsData) do
    createKeybindRow(name, kcode)
end

-- ==========================================
-- COMBAT / MOVEMENT HELPER BUILDERS
-- ==========================================
local function createCombatHeader(headerText)
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 15)
    header.BackgroundTransparency = 1
    header.Text = headerText
    header.TextColor3 = Color3.fromRGB(168, 85, 247)
    header.TextSize = 7
    header.Font = Enum.Font.GothamBold
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = combatPage
    return header
end

local function createCombatToggleBox(titleText, defaultState, onToggleCallback)
    local boxFrame = Instance.new("Frame")
    boxFrame.Size = UDim2.new(1, 0, 0, 24)
    boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    boxFrame.Parent = combatPage

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = boxFrame

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.fromRGB(30, 30, 30)
    boxStroke.Thickness = 1
    boxStroke.Parent = boxFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = titleText
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 8
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = boxFrame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 32, 0, 16)
    toggleBtn.Position = UDim2.new(1, -40, 0.5, -8)
    toggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(25, 25, 30)
    toggleBtn.Text = ""
    toggleBtn.Parent = boxFrame

    local toggleBtnCorner = Instance.new("UICorner")
    toggleBtnCorner.CornerRadius = UDim.new(1, 0)
    toggleBtnCorner.Parent = toggleBtn

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 12, 0, 12)
    circle.Position = defaultState and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.Parent = toggleBtn

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = circle

    local currentState = defaultState

    toggleBtn.MouseButton1Click:Connect(function()
        currentState = not currentState
        if currentState then
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(168, 85, 247)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(1, -14, 0.5, -6)}):Play()
        else
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 30)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -6)}):Play()
        end
        onToggleCallback(currentState)
    end)

    return toggleBtn
end

local function createCombatSpeedBox(titleText, defaultValue, onSaveCallback)
    local boxFrame = Instance.new("Frame")
    boxFrame.Size = UDim2.new(1, 0, 0, 24)
    boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    boxFrame.Parent = combatPage

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = boxFrame

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.fromRGB(30, 30, 30)
    boxStroke.Thickness = 1
    boxStroke.Parent = boxFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = titleText
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 8
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = boxFrame

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0, 48, 0, 16)
    input.Position = UDim2.new(1, -56, 0.5, -8)
    input.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    input.Text = tostring(defaultValue)
    input.TextColor3 = Color3.fromRGB(168, 85, 247)
    input.TextSize = 8
    input.Font = Enum.Font.GothamBold
    input.ClearTextOnFocus = false
    input.Parent = boxFrame

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 3)
    inputCorner.Parent = input

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(168, 85, 247)
    inputStroke.Transparency = 0.5
    inputStroke.Thickness = 1
    inputStroke.Parent = input

    input.FocusLost:Connect(function()
        local num = tonumber(input.Text)
        if num then onSaveCallback(num)
        else input.Text = tostring(defaultValue) end
    end)

    return input
end

createCombatHeader("ANTI DESYNC BAT")
createCombatToggleBox("Auto Swing", antiDesyncAutoSwingEnabled, function(state) antiDesyncAutoSwingEnabled = state end)

createCombatHeader("COUNTERS & MODULES")
createCombatToggleBox("Anti Die", antiDieEnabled, function(state) toggleAntiDie(state) end)
createCombatToggleBox("Bat Counter", batCounterEnabled, function(state) batCounterEnabled = state end)
createCombatToggleBox("Med Counter", medCounterEnabled, function(state) medCounterEnabled = state end)

createCombatToggleBox("No Player Collision", noPlayerCollisionEnabled, function(state)
    noPlayerCollisionEnabled = state
    if not state then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end)

createCombatHeader("AUTO STEAL SETTINGS")
createCombatToggleBox("Auto Steal", autoStealEnabled, function(state) autoStealEnabled = state end)
createCombatSpeedBox("Radius", autoStealRadius, function(val) autoStealRadius = val end)

-- ==========================================
-- 5. Movement Page Elements & Settings
-- ==========================================
local configFileName = "SoundHub_Config.json"

local normalSpeedValue = 50
local carrySpeedValue = 37
local laggerSpeedValue = 45
local laggerCarrySpeedValue = 25
local extraSpeedValue = 34
local extraCarrySpeedValue = 29
local autoTpDownValue = false
local autoTpHeightValue = 10
local antiRagdollValue = false

local State = { infJumpEnabled = false, infJumpMode = "hold", holdInfJumpConn = nil }
local activeSpeedMode = "Normal"
local isAutoLeftActive = false

-- ==========================================
-- ANIMATION PACK SYSTEM
-- ==========================================
local AnimationPacks = {
    ["Zombie"] = {
        idle = {{"rbxassetid://616158929", 1}, {"rbxassetid://616158929", 1}},
        walk = "rbxassetid://616168032", run = "rbxassetid://616163682",
        jump = "rbxassetid://616161997", fall = "rbxassetid://616157476", climb = "rbxassetid://616156119"
    },
    ["Ninja"] = {
        idle = {{"rbxassetid://656117400", 1}, {"rbxassetid://656117400", 1}},
        walk = "rbxassetid://656121766", run = "rbxassetid://656118852",
        jump = "rbxassetid://656117878", fall = "rbxassetid://656115606", climb = "rbxassetid://656114359"
    },
    ["Knight"] = {
        idle = {{"rbxassetid://657595757", 1}, {"rbxassetid://657595757", 1}},
        walk = "rbxassetid://657552124", run = "rbxassetid://657564596",
        jump = "rbxassetid://658409194", fall = "rbxassetid://657600338", climb = "rbxassetid://658360781"
    },
    ["Pirate"] = {
        idle = {{"rbxassetid://750781874", 1}, {"rbxassetid://750781874", 1}},
        walk = "rbxassetid://750785693", run = "rbxassetid://750783738",
        jump = "rbxassetid://750782230", fall = "rbxassetid://750780242", climb = "rbxassetid://750779899"
    },
    ["Stylish"] = {
        idle = {{"rbxassetid://616136790", 1}, {"rbxassetid://616136790", 1}},
        walk = "rbxassetid://616146177", run = "rbxassetid://616140816",
        jump = "rbxassetid://616139451", fall = "rbxassetid://616134815", climb = "rbxassetid://616133594"
    },
}

local HIT_HARDER_ANIMS = {
    idle1 = "rbxassetid://133806214992291", idle2 = "rbxassetid://94970088341563",
    walk = "rbxassetid://707897309", run = "rbxassetid://707861613",
    jump = "rbxassetid://116936326516985", fall = "rbxassetid://116936326516985",
}

local AnimationPackList = {"OFF", "Unwalk", "Hit Harder", "Zombie", "Ninja", "Knight", "Pirate", "Stylish"}
local AnimationPackIndex = 1
local OriginalAnims = {}
local unwalkSavedAnimate = nil
local selectedAnimationPack = "OFF"
local unwalkEnabled = false
local hitHarderAnimEnabled = false

local function getAnimate(char) char = char or LocalPlayer.Character; return char and char:FindFirstChild("Animate") or nil end

local function stopCurrentAnimations(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do pcall(function() track:Stop(0) end) end
end

local function backupAnimations(char)
    local animate = getAnimate(char)
    if not animate or next(OriginalAnims) ~= nil then return end
    local function getId(obj) return obj and obj.AnimationId or nil end
    OriginalAnims = {
        idle1 = getId(animate.idle and animate.idle:FindFirstChild("Animation1")),
        idle2 = getId(animate.idle and animate.idle:FindFirstChild("Animation2")),
        walk = getId(animate.walk and animate.walk:FindFirstChild("WalkAnim")),
        run = getId(animate.run and animate.run:FindFirstChild("RunAnim")),
        jump = getId(animate.jump and animate.jump:FindFirstChild("JumpAnim")),
        fall = getId(animate.fall and animate.fall:FindFirstChild("FallAnim")),
        climb = getId(animate.climb and animate.climb:FindFirstChild("ClimbAnim")),
    }
end

local function setAnimId(obj, id)
    if obj and id then pcall(function() obj.AnimationId = id end) end
end

local function reloadAnimate(animate)
    if not animate then return end
    pcall(function() animate.Disabled = true; task.wait(); animate.Disabled = false end)
end

local function resetAnimations()
    local char = LocalPlayer.Character
    local animate = getAnimate(char)
    if not animate or next(OriginalAnims) == nil then return end
    stopCurrentAnimations(char)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), OriginalAnims.idle1)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), OriginalAnims.idle2)
    setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"), OriginalAnims.walk)
    setAnimId(animate.run and animate.run:FindFirstChild("RunAnim"), OriginalAnims.run)
    setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"), OriginalAnims.jump)
    setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"), OriginalAnims.fall)
    setAnimId(animate.climb and animate.climb:FindFirstChild("ClimbAnim"), OriginalAnims.climb)
    reloadAnimate(animate)
end

local function applyAnimationPack(packName)
    selectedAnimationPack = packName or "OFF"
    if selectedAnimationPack ~= "Unwalk" and unwalkEnabled then disableUnwalk() end
    if selectedAnimationPack ~= "Hit Harder" and hitHarderAnimEnabled then hitHarderAnimEnabled = false; resetAnimations() end
    if selectedAnimationPack == "Unwalk" then resetAnimations(); enableUnwalk(); return end
    if selectedAnimationPack == "Hit Harder" then disableUnwalk(); enableHitHarderAnim(); return end
    if selectedAnimationPack == "OFF" then resetAnimations(); return end
    local pack = AnimationPacks[selectedAnimationPack]
    local char = LocalPlayer.Character
    local animate = getAnimate(char)
    if not pack or not animate then return end
    backupAnimations(char)
    stopCurrentAnimations(char)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), pack.idle[1][1])
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), pack.idle[2][1])
    setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"), pack.walk)
    setAnimId(animate.run and animate.run:FindFirstChild("RunAnim"), pack.run)
    setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"), pack.jump)
    setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"), pack.fall)
    setAnimId(animate.climb and animate.climb:FindFirstChild("ClimbAnim"), pack.climb)
    reloadAnimate(animate)
end

function enableUnwalk()
    unwalkEnabled = true
    local char = LocalPlayer.Character
    local animate = getAnimate(char)
    if animate then
        if not unwalkSavedAnimate then unwalkSavedAnimate = animate:Clone() end
        stopCurrentAnimations(char)
        animate:Destroy()
    end
end

function disableUnwalk()
    unwalkEnabled = false
    local char = LocalPlayer.Character
    if char and not char:FindFirstChild("Animate") and unwalkSavedAnimate then
        local newAnimate = unwalkSavedAnimate:Clone()
        newAnimate.Parent = char
    end
end

function enableHitHarderAnim()
    hitHarderAnimEnabled = true
    local char = LocalPlayer.Character
    local animate = getAnimate(char)
    if not animate then return end
    backupAnimations(char)
    stopCurrentAnimations(char)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), HIT_HARDER_ANIMS.idle1)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), HIT_HARDER_ANIMS.idle2)
    setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"), HIT_HARDER_ANIMS.walk)
    setAnimId(animate.run and animate.run:FindFirstChild("RunAnim"), HIT_HARDER_ANIMS.run)
    setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"), HIT_HARDER_ANIMS.jump)
    setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"), HIT_HARDER_ANIMS.fall)
    reloadAnimate(animate)
end

function disableHitHarderAnim()
    hitHarderAnimEnabled = false
    resetAnimations()
    if selectedAnimationPack ~= "OFF" then task.wait(); applyAnimationPack(selectedAnimationPack) end
end

function syncAnimationPackIndex()
    for i, name in ipairs(AnimationPackList) do
        if name == selectedAnimationPack then AnimationPackIndex = i; return end
    end
    selectedAnimationPack = "OFF"
    AnimationPackIndex = 1
end

function applySavedAnimationPackToCharacter(char)
    syncAnimationPackIndex()
    if not char then char = LocalPlayer.Character end
    if not char then return end
    local animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 6)
    if not animate then return end
    task.wait(0.2)
    OriginalAnims = {}
    unwalkSavedAnimate = nil
    if selectedAnimationPack and selectedAnimationPack ~= "OFF" then
        pcall(function() applyAnimationPack(selectedAnimationPack) end)
    else
        pcall(function() resetAnimations() end)
    end
end

local function getModeBaseSpeed()
    if activeSpeedMode:find("Lagger") then return laggerSpeedValue
    elseif activeSpeedMode:find("Extra") then return extraSpeedValue
    else return normalSpeedValue end
end

local function getCurrentSpeed()
    local isCarryActive = activeSpeedMode:find("Carry") ~= nil
    if activeSpeedMode:find("Lagger") then return isCarryActive and laggerCarrySpeedValue or laggerSpeedValue
    elseif activeSpeedMode:find("Extra") then return isCarryActive and extraCarrySpeedValue or extraSpeedValue
    else return isCarryActive and carrySpeedValue or normalSpeedValue end
end

local function saveAllSettings()
    if writefile then
        pcall(function()
            local settingsData = {
                NormalSpeed = normalSpeedValue, CarrySpeed = carrySpeedValue,
                LaggerSpeed = laggerSpeedValue, LaggerCarrySpeed = laggerCarrySpeedValue,
                ExtraSpeed = extraSpeedValue, ExtraCarrySpeed = extraCarrySpeedValue,
                AutoTpDown = autoTpDownValue, AutoTpHeight = autoTpHeightValue,
                AntiRagdoll = antiRagdollValue,
                InfiniteJump = State.infJumpEnabled, InfiniteJumpMode = State.infJumpMode,
                AnimationPack = selectedAnimationPack
            }
            writefile(configFileName, HttpService:JSONEncode(settingsData))
        end)
    end
end

local function loadAllSettings()
    if isfile and readfile and isfile(configFileName) then
        pcall(function()
            local decoded = HttpService:JSONDecode(readfile(configFileName))
            if decoded then
                if decoded.NormalSpeed then normalSpeedValue = decoded.NormalSpeed end
                if decoded.CarrySpeed then carrySpeedValue = decoded.CarrySpeed end
                if decoded.LaggerSpeed then laggerSpeedValue = decoded.LaggerSpeed end
                if decoded.LaggerCarrySpeed then laggerCarrySpeedValue = decoded.LaggerCarrySpeed end
                if decoded.ExtraSpeed then extraSpeedValue = decoded.ExtraSpeed end
                if decoded.ExtraCarrySpeed then extraCarrySpeedValue = decoded.ExtraCarrySpeed end
                if decoded.AutoTpDown ~= nil then autoTpDownValue = decoded.AutoTpDown end
                if decoded.AutoTpHeight then autoTpHeightValue = decoded.AutoTpHeight end
                if decoded.AntiRagdoll ~= nil then antiRagdollValue = decoded.AntiRagdoll end
                if decoded.InfiniteJump ~= nil then State.infJumpEnabled = decoded.InfiniteJump end
                if decoded.InfiniteJumpMode then State.infJumpMode = decoded.InfiniteJumpMode end
                if decoded.AnimationPack then selectedAnimationPack = decoded.AnimationPack; syncAnimationPackIndex() end
            end
        end)
    end
end

loadAllSettings()

local function createSpeedHeader(headerText)
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 15)
    header.BackgroundTransparency = 1
    header.Text = headerText
    header.TextColor3 = Color3.fromRGB(168, 85, 247)
    header.TextSize = 7
    header.Font = Enum.Font.GothamBold
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = speedPage
    return header
end

createSpeedHeader("• SPEED CONFIG")

local function createSpeedConfigCard(mainTitle, subText, defaultNormVal, defaultStealVal, onNormChange, onStealChange)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 42)
    card.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    card.Parent = speedPage
    local cardCorner = Instance.new("UICorner"); cardCorner.CornerRadius = UDim.new(0, 6); cardCorner.Parent = card
    local cardStroke = Instance.new("UIStroke"); cardStroke.Color = Color3.fromRGB(35, 35, 35); cardStroke.Thickness = 1; cardStroke.Parent = card
    local titleLbl = Instance.new("TextLabel"); titleLbl.Size = UDim2.new(0.42, 0, 0, 16); titleLbl.Position = UDim2.new(0, 8, 0, 4)
    titleLbl.BackgroundTransparency = 1; titleLbl.Text = mainTitle; titleLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
    titleLbl.TextSize = 9; titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = card
    local subLbl = Instance.new("TextLabel"); subLbl.Size = UDim2.new(0.42, 0, 0, 14); subLbl.Position = UDim2.new(0, 8, 0, 20)
    subLbl.BackgroundTransparency = 1; subLbl.Text = subText; subLbl.TextColor3 = Color3.fromRGB(110, 110, 110)
    subLbl.TextSize = 7.5; subLbl.Font = Enum.Font.Gotham; subLbl.TextXAlignment = Enum.TextXAlignment.Left; subLbl.Parent = card
    local normHeader = Instance.new("TextLabel"); normHeader.Size = UDim2.new(0, 45, 0, 12); normHeader.Position = UDim2.new(1, -98, 0, 4)
    normHeader.BackgroundTransparency = 1; normHeader.Text = "norm spd"; normHeader.TextColor3 = Color3.fromRGB(160, 160, 160)
    normHeader.TextSize = 7; normHeader.Font = Enum.Font.Gotham; normHeader.TextXAlignment = Enum.TextXAlignment.Center; normHeader.Parent = card
    local normBox = Instance.new("TextBox"); normBox.Size = UDim2.new(0, 40, 0, 16); normBox.Position = UDim2.new(1, -95, 0, 18)
    normBox.BackgroundColor3 = Color3.fromRGB(6, 6, 6); normBox.Text = tostring(defaultNormVal)
    normBox.TextColor3 = Color3.fromRGB(255, 255, 255); normBox.TextSize = 8.5; normBox.Font = Enum.Font.GothamBold
    normBox.ClearTextOnFocus = false; normBox.Parent = card
    local nCorner = Instance.new("UICorner"); nCorner.CornerRadius = UDim.new(0, 3); nCorner.Parent = normBox
    local nStroke = Instance.new("UIStroke"); nStroke.Color = Color3.fromRGB(40, 40, 40); nStroke.Thickness = 1; nStroke.Parent = normBox
    local stealHeader = Instance.new("TextLabel"); stealHeader.Size = UDim2.new(0, 45, 0, 12); stealHeader.Position = UDim2.new(1, -48, 0, 4)
    stealHeader.BackgroundTransparency = 1; stealHeader.Text = "steal spd"; stealHeader.TextColor3 = Color3.fromRGB(160, 160, 160)
    stealHeader.TextSize = 7; stealHeader.Font = Enum.Font.Gotham; stealHeader.TextXAlignment = Enum.TextXAlignment.Center; stealHeader.Parent = card
    local stealBox = Instance.new("TextBox"); stealBox.Size = UDim2.new(0, 40, 0, 16); stealBox.Position = UDim2.new(1, -45, 0, 18)
    stealBox.BackgroundColor3 = Color3.fromRGB(6, 6, 6); stealBox.Text = tostring(defaultStealVal)
    stealBox.TextColor3 = Color3.fromRGB(255, 255, 255); stealBox.TextSize = 8.5; stealBox.Font = Enum.Font.GothamBold
    stealBox.ClearTextOnFocus = false; stealBox.Parent = card
    local sCorner = Instance.new("UICorner"); sCorner.CornerRadius = UDim.new(0, 3); sCorner.Parent = stealBox
    local sStroke = Instance.new("UIStroke"); sStroke.Color = Color3.fromRGB(40, 40, 40); sStroke.Thickness = 1; sStroke.Parent = stealBox
    normBox.FocusLost:Connect(function()
        local val = tonumber(normBox.Text)
        if val then onNormChange(val); saveAllSettings() else normBox.Text = tostring(defaultNormVal) end
    end)
    stealBox.FocusLost:Connect(function()
        local val = tonumber(stealBox.Text)
        if val then onStealChange(val); saveAllSettings() else stealBox.Text = tostring(defaultStealVal) end
    end)
    return card
end

createSpeedConfigCard("Normal Speed", "default mode", normalSpeedValue, carrySpeedValue, function(v) normalSpeedValue = v end, function(v) carrySpeedValue = v end)
createSpeedConfigCard("Lagger Speed", "use against lagger", laggerSpeedValue, laggerCarrySpeedValue, function(v) laggerSpeedValue = v end, function(v) laggerCarrySpeedValue = v end)
createSpeedConfigCard("Extra Speed", "use for whatever", extraSpeedValue, extraCarrySpeedValue, function(v) extraSpeedValue = v end, function(v) extraCarrySpeedValue = v end)

local function createSpeedBox(titleText, defaultValue, onSaveCallback)
    local boxFrame = Instance.new("Frame"); boxFrame.Size = UDim2.new(1, 0, 0, 24)
    boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12); boxFrame.Parent = speedPage
    local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = boxFrame
    local boxStroke = Instance.new("UIStroke"); boxStroke.Color = Color3.fromRGB(30, 30, 30); boxStroke.Thickness = 1; boxStroke.Parent = boxFrame
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.6, 0, 1, 0); label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1; label.Text = titleText; label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 8; label.Font = Enum.Font.GothamBold; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = boxFrame
    local input = Instance.new("TextBox"); input.Size = UDim2.new(0, 48, 0, 16); input.Position = UDim2.new(1, -56, 0.5, -8)
    input.BackgroundColor3 = Color3.fromRGB(6, 6, 6); input.Text = tostring(defaultValue)
    input.TextColor3 = Color3.fromRGB(168, 85, 247); input.TextSize = 8; input.Font = Enum.Font.GothamBold
    input.ClearTextOnFocus = false; input.Parent = boxFrame
    local inputCorner = Instance.new("UICorner"); inputCorner.CornerRadius = UDim.new(0, 3); inputCorner.Parent = input
    local inputStroke = Instance.new("UIStroke"); inputStroke.Color = Color3.fromRGB(168, 85, 247)
    inputStroke.Transparency = 0.5; inputStroke.Thickness = 1; inputStroke.Parent = input
    input.FocusLost:Connect(function()
        local num = tonumber(input.Text)
        if num then onSaveCallback(num); saveAllSettings() else input.Text = tostring(defaultValue) end
    end)
    return input
end

local function createToggleBox(titleText, defaultState, onToggleCallback)
    local boxFrame = Instance.new("Frame"); boxFrame.Size = UDim2.new(1, 0, 0, 24)
    boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12); boxFrame.Parent = speedPage
    local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = boxFrame
    local boxStroke = Instance.new("UIStroke"); boxStroke.Color = Color3.fromRGB(30, 30, 30); boxStroke.Thickness = 1; boxStroke.Parent = boxFrame
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.6, 0, 1, 0); label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1; label.Text = titleText; label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 8; label.Font = Enum.Font.GothamBold; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = boxFrame
    local toggleBtn = Instance.new("TextButton"); toggleBtn.Size = UDim2.new(0, 32, 0, 16); toggleBtn.Position = UDim2.new(1, -40, 0.5, -8)
    toggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(25, 25, 30)
    toggleBtn.Text = ""; toggleBtn.Parent = boxFrame
    local toggleBtnCorner = Instance.new("UICorner"); toggleBtnCorner.CornerRadius = UDim.new(1, 0); toggleBtnCorner.Parent = toggleBtn
    local circle = Instance.new("Frame"); circle.Size = UDim2.new(0, 12, 0, 12)
    circle.Position = defaultState and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255); circle.Parent = toggleBtn
    local circleCorner = Instance.new("UICorner"); circleCorner.CornerRadius = UDim.new(1, 0); circleCorner.Parent = circle
    local currentState = defaultState
    toggleBtn.MouseButton1Click:Connect(function()
        currentState = not currentState
        if currentState then
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(168, 85, 247)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(1, -14, 0.5, -6)}):Play()
        else
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 30)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -6)}):Play()
        end
        onToggleCallback(currentState); saveAllSettings()
    end)
    return toggleBtn
end

createSpeedHeader("TELEPORT")
createToggleBox("Auto TP Down", autoTpDownValue, function(state) autoTpDownValue = state end)
createSpeedBox("Height", autoTpHeightValue, function(val) autoTpHeightValue = val end)

createSpeedHeader("JUMP")

-- ANIMATION PACK UI
local animBox = Instance.new("Frame"); animBox.Size = UDim2.new(1, 0, 0, 24)
animBox.BackgroundColor3 = Color3.fromRGB(12, 12, 12); animBox.Parent = speedPage
local animCorner = Instance.new("UICorner"); animCorner.CornerRadius = UDim.new(0, 4); animCorner.Parent = animBox
local animStroke = Instance.new("UIStroke"); animStroke.Color = Color3.fromRGB(30, 30, 30); animStroke.Thickness = 1; animStroke.Parent = animBox
local animLabel = Instance.new("TextLabel"); animLabel.Size = UDim2.new(0.4, 0, 1, 0); animLabel.Position = UDim2.new(0, 8, 0, 0)
animLabel.BackgroundTransparency = 1; animLabel.Text = "Animation Pack"; animLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
animLabel.TextSize = 8; animLabel.Font = Enum.Font.GothamBold; animLabel.TextXAlignment = Enum.TextXAlignment.Left; animLabel.Parent = animBox
local leftAnimBtn = Instance.new("TextButton"); leftAnimBtn.Size = UDim2.new(0, 18, 0, 16); leftAnimBtn.Position = UDim2.new(1, -95, 0.5, -8)
leftAnimBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25); leftAnimBtn.Text = "<"
leftAnimBtn.TextColor3 = Color3.fromRGB(168, 85, 247); leftAnimBtn.TextSize = 8; leftAnimBtn.Font = Enum.Font.GothamBold; leftAnimBtn.Parent = animBox
local leftCorner = Instance.new("UICorner"); leftCorner.CornerRadius = UDim.new(0, 3); leftCorner.Parent = leftAnimBtn
local animValueLabel = Instance.new("TextLabel"); animValueLabel.Size = UDim2.new(0, 50, 0, 16); animValueLabel.Position = UDim2.new(1, -74, 0.5, -8)
animValueLabel.BackgroundTransparency = 1; animValueLabel.Text = selectedAnimationPack
animValueLabel.TextColor3 = Color3.fromRGB(168, 85, 247); animValueLabel.TextSize = 8; animValueLabel.Font = Enum.Font.GothamBold; animValueLabel.Parent = animBox
local rightAnimBtn = Instance.new("TextButton"); rightAnimBtn.Size = UDim2.new(0, 18, 0, 16); rightAnimBtn.Position = UDim2.new(1, -22, 0.5, -8)
rightAnimBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25); rightAnimBtn.Text = ">"
rightAnimBtn.TextColor3 = Color3.fromRGB(168, 85, 247); rightAnimBtn.TextSize = 8; rightAnimBtn.Font = Enum.Font.GothamBold; rightAnimBtn.Parent = animBox
local rightCorner = Instance.new("UICorner"); rightCorner.CornerRadius = UDim.new(0, 3); rightCorner.Parent = rightAnimBtn

leftAnimBtn.MouseButton1Click:Connect(function()
    AnimationPackIndex = AnimationPackIndex - 1
    if AnimationPackIndex < 1 then AnimationPackIndex = #AnimationPackList end
    selectedAnimationPack = AnimationPackList[AnimationPackIndex]
    animValueLabel.Text = selectedAnimationPack
    applyAnimationPack(selectedAnimationPack)
    saveAllSettings()
end)

rightAnimBtn.MouseButton1Click:Connect(function()
    AnimationPackIndex = AnimationPackIndex + 1
    if AnimationPackIndex > #AnimationPackList then AnimationPackIndex = 1 end
    selectedAnimationPack = AnimationPackList[AnimationPackIndex]
    animValueLabel.Text = selectedAnimationPack
    applyAnimationPack(selectedAnimationPack)
    saveAllSettings()
end)

syncAnimationPackIndex()
task.defer(function() applySavedAnimationPackToCharacter(LocalPlayer.Character) end)
LocalPlayer.CharacterAdded:Connect(function(char) task.wait(0.65); applySavedAnimationPackToCharacter(char) end)

local function startHoldInfJump()
    if State.holdInfJumpConn then State.holdInfJumpConn:Disconnect() end
    State.holdInfJumpConn = RunService.Heartbeat:Connect(function()
        if not State.infJumpEnabled or State.infJumpMode ~= "hold" then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        local isJumpHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space) or (hum.Jump == true)
        if isJumpHeld and root.Velocity.Y < 35 then root.Velocity = Vector3.new(root.Velocity.X, 55, root.Velocity.Z) end
        if root.Velocity.Y < -120 then root.Velocity = Vector3.new(root.Velocity.X, -120, root.Velocity.Z) end
    end)
end

local function stopHoldInfJump()
    if State.holdInfJumpConn then State.holdInfJumpConn:Disconnect(); State.holdInfJumpConn = nil end
end

local function setupManualInfJump()
    UserInputService.JumpRequest:Connect(function()
        if not State.infJumpEnabled or State.infJumpMode ~= "manual" then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.Velocity = Vector3.new(root.Velocity.X, 55, root.Velocity.Z) end
    end)
end

setupManualInfJump()

local function applyInfJumpMode()
    if State.infJumpEnabled then
        if State.infJumpMode == "hold" then startHoldInfJump() else stopHoldInfJump() end
    else stopHoldInfJump() end
end

applyInfJumpMode()

createToggleBox("Infinite Jump", State.infJumpEnabled, function(state) State.infJumpEnabled = state; applyInfJumpMode() end)

local antiRagdollConns = {}

local function cleanRagdoll(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if hum then
        local s = hum:GetState()
        if s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.Ragdoll or s == Enum.HumanoidStateType.FallingDown then
            if hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Running) end
        end
        Camera.CameraSubject = hum
    end
    if root then root.Anchored = false; root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end
end

local function startAntiRagdollLoops(char)
    local antiConn = RunService.Heartbeat:Connect(function()
        if not antiRagdollValue then return end
        if not LocalPlayer.Character then return end
        local c = LocalPlayer.Character
        local hum = c:FindFirstChildOfClass("Humanoid")
        local root = c:FindFirstChild("HumanoidRootPart")
        if not (hum and root) then return end
        local s = hum:GetState()
        local ragdolled = (s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.Ragdoll or s == Enum.HumanoidStateType.FallingDown)
        if ragdolled then cleanRagdoll(c) end
    end)
    table.insert(antiRagdollConns, antiConn)
end

local function stopAntiRagdoll()
    for _, c in pairs(antiRagdollConns) do pcall(function() c:Disconnect() end) end
    antiRagdollConns = {}
end

createToggleBox("Anti-Ragdoll", antiRagdollValue, function(state)
    antiRagdollValue = state
    if antiRagdollValue then
        if LocalPlayer.Character then startAntiRagdollLoops(LocalPlayer.Character) end
    else stopAntiRagdoll() end
end)

local speedTags = {}

local function setupSpeedTag(character)
    if character ~= LocalPlayer.Character then return end
    local head = character:WaitForChild("Head", 3)
    if not head then return end
    if head:FindFirstChild("SoundHubSpeedTag") then head.SoundHubSpeedTag:Destroy() end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SoundHubSpeedTag"
    billboard.Size = UDim2.new(0, 130, 0, 36)
    billboard.StudsOffset = Vector3.new(0, 2.2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head
    local mainBg = Instance.new("Frame")
    mainBg.Size = UDim2.new(1, 0, 1, 0)
    mainBg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainBg.BackgroundTransparency = 0.2
    mainBg.ClipsDescendants = true
    mainBg.Parent = billboard
    local mainCorner = Instance.new("UICorner"); mainCorner.CornerRadius = UDim.new(0, 6); mainCorner.Parent = mainBg
    local mainStroke = Instance.new("UIStroke"); mainStroke.Color = Color3.fromRGB(168, 85, 247); mainStroke.Thickness = 1; mainStroke.Parent = mainBg
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    progressFill.BackgroundTransparency = 0.65
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 1
    progressFill.Parent = mainBg
    local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(0, 6); fillCorner.Parent = progressFill
    local linkLabel = Instance.new("TextLabel")
    linkLabel.Size = UDim2.new(1, 0, 0, 12)
    linkLabel.Position = UDim2.new(0, 0, 0, 2)
    linkLabel.BackgroundTransparency = 1
    linkLabel.ZIndex = 3
    linkLabel.Text = "discord.gg/HCxUsWKJte"
    linkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    linkLabel.TextSize = 7.5
    linkLabel.Font = Enum.Font.GothamBold
    linkLabel.Parent = mainBg
    local infoContainer = Instance.new("Frame")
    infoContainer.Size = UDim2.new(1, -6, 0, 18)
    infoContainer.Position = UDim2.new(0, 3, 0, 15)
    infoContainer.BackgroundTransparency = 1
    infoContainer.ZIndex = 3
    infoContainer.Parent = mainBg
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = infoContainer
    local function createStatColumn(nameText)
        local col = Instance.new("Frame")
        col.Size = UDim2.new(0, 36, 1, 0)
        col.BackgroundTransparency = 1
        col.ZIndex = 3
        col.Parent = infoContainer
        local lblTop = Instance.new("TextLabel")
        lblTop.Size = UDim2.new(1, 0, 0, 8)
        lblTop.BackgroundTransparency = 1
        lblTop.ZIndex = 3
        lblTop.Text = nameText
        lblTop.TextColor3 = Color3.fromRGB(140, 140, 140)
        lblTop.TextSize = 5.5
        lblTop.Font = Enum.Font.GothamBold
        lblTop.TextXAlignment = Enum.TextXAlignment.Center
        lblTop.Parent = col
        local lblVal = Instance.new("TextLabel")
        lblVal.Name = "Value"
        lblVal.Size = UDim2.new(1, 0, 0, 10)
        lblVal.Position = UDim2.new(0, 0, 0, 8)
        lblVal.BackgroundTransparency = 1
        lblVal.ZIndex = 3
        lblVal.Text = "0"
        lblVal.TextColor3 = Color3.fromRGB(255, 255, 255)
        lblVal.TextSize = 7.5
        lblVal.Font = Enum.Font.GothamBold
        lblVal.TextXAlignment = Enum.TextXAlignment.Center
        lblVal.Parent = col
        return lblVal
    end
    local fpsVal = createStatColumn("FPS")
    local pingVal = createStatColumn("PING")
    local speedVal = createStatColumn("SPEED")
    speedTags[character] = {Fps = fpsVal, Ping = pingVal, Speed = speedVal, FillBar = progressFill}
end

LocalPlayer.CharacterAdded:Connect(function(char) task.wait(0.5); setupSpeedTag(char) end)
if LocalPlayer.Character then setupSpeedTag(LocalPlayer.Character) end

local function teleportDown()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local rayOrigin = hrp.Position
    local rayDirection = Vector3.new(0, -300, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {char}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if raycastResult then
        local groundPos = raycastResult.Position
        hrp.CFrame = CFrame.new(groundPos + Vector3.new(0, 3.0, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

local function doDrop()
    if dropActive then return end
    local char = LocalPlayer.Character
    if not char then return end
    local r = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not r or not hum then return end
    dropActive = true
    local startTime = tick()
    local ascendConnection
    ascendConnection = RunService.Heartbeat:Connect(function()
        if tick() - startTime < DROP_ASCEND_DURATION then
            r.Velocity = Vector3.new(r.Velocity.X, DROP_ASCEND_SPEED, r.Velocity.Z)
        else
            ascendConnection:Disconnect()
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {char}
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local rr = Workspace:Raycast(r.Position, Vector3.new(0, -2000, 0), rp)
            if rr then
                local off = (hum.HipHeight or 2) + 1.5
                r.CFrame = CFrame.new(r.Position.X, rr.Position.Y + off, r.Position.Z)
                r.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
            dropActive = false
        end
    end)
end

local isJumpingForTp = false

local function getHRP()
    local c = LocalPlayer.Character
    if c then return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") end
    return nil
end

local function isMyPlotByName(pn)
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(pn)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
    end
    return false
end

local function findNearestPrompt()
    local hrp = getHRP()
    if not hrp then return nil end
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local nearest, dist = nil, math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local pods = plot:FindFirstChild("AnimalPodiums")
        if not pods then continue end
        for _, pod in ipairs(pods:GetChildren()) do
            local base = pod:FindFirstChild("Base")
            if not base then continue end
            local spawn = base:FindFirstChild("Spawn")
            if not spawn then continue end
            local d = (spawn.Position - hrp.Position).Magnitude
            if d <= autoStealRadius and d < dist then
                local att = spawn:FindFirstChild("PromptAttachment")
                if att then
                    for _, p in ipairs(att:GetChildren()) do
                        if p:IsA("ProximityPrompt") and p.ActionText and p.ActionText:find("Steal") then
                            nearest, dist = p, d
                        end
                    end
                end
            end
        end
    end
    return nearest
end

local function executeSteal(prompt, updateProgressCallback)
    if isStealing then return end
    if not StealData[prompt] then
        StealData[prompt] = {hold = {}, trigger = {}, ready = true}
        if getconnections then
            for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                if c.Function then table.insert(StealData[prompt].hold, c.Function) end
            end
            for _, c in ipairs(getconnections(prompt.Triggered)) do
                if c.Function then table.insert(StealData[prompt].trigger, c.Function) end
            end
        end
    end
    local data = StealData[prompt]
    if not data.ready then return end
    data.ready = false
    isStealing = true
    local startTime = tick()
    task.spawn(function()
        for _, f in ipairs(data.hold) do pcall(f) end
        while tick() - startTime < STEAL_DURATION do
            local elapsed = tick() - startTime
            local p = math.clamp(elapsed / STEAL_DURATION, 0, 1)
            updateProgressCallback(p, math.floor(p * 100))
            RunService.Heartbeat:Wait()
        end
        updateProgressCallback(1, 100)
        for _, f in ipairs(data.trigger) do pcall(f) end
        task.wait(0.1)
        updateProgressCallback(0, 0)
        data.ready = true
        isStealing = false
    end)
end

RunService.Heartbeat:Connect(function()
    if autoStealEnabled and not isStealing then
        local success, prompt = pcall(findNearestPrompt)
        if success and prompt then
            pcall(function()
                executeSteal(prompt, function(p, val)
                    local char = LocalPlayer.Character
                    if char and speedTags[char] and speedTags[char].FillBar then
                        speedTags[char].FillBar.Size = UDim2.new(p, 0, 1, 0)
                    end
                end)
            end)
        end
    end

    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if humanoid and hrp then
            local targetSpeed = getCurrentSpeed()
            humanoid.WalkSpeed = targetSpeed
            if not isAutoLeftActive then
                if humanoid.MoveDirection.Magnitude > 0 then
                    local moveDir = humanoid.MoveDirection.Unit
                    hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * targetSpeed, math.clamp(hrp.AssemblyLinearVelocity.Y, -50, 50), moveDir.Z * targetSpeed)
                end
            end
            if autoTpDownValue and not isAutoLeftActive then
                local rayOrigin = hrp.Position
                local rayDirection = Vector3.new(0, -300, 0)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {char}
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                if raycastResult then
                    local currentHeightAboveGround = (hrp.Position - raycastResult.Position).Magnitude
                    local currentState = humanoid:GetState()
                    local targetHeightThreshold = autoTpHeightValue * 3.5
                    if currentState == Enum.HumanoidStateType.Jumping or currentState == Enum.HumanoidStateType.Freefall then
                        if currentHeightAboveGround >= (targetHeightThreshold - 1) then isJumpingForTp = true end
                        if isJumpingForTp and currentHeightAboveGround >= targetHeightThreshold then
                            local groundPos = raycastResult.Position
                            hrp.CFrame = CFrame.new(groundPos + Vector3.new(0, 3.0, 0))
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            isJumpingForTp = false
                        end
                    else
                        if humanoid.FloorMaterial ~= Enum.Material.Air then isJumpingForTp = false end
                    end
                end
            end
        end
    end

    local c = LocalPlayer.Character
    if c and speedTags[c] and c.PrimaryPart then
        local h = c:FindFirstChildOfClass("Humanoid")
        local part = c.PrimaryPart
        if h and part then
            local vel = part.AssemblyLinearVelocity
            local currentSpeed = math.floor(Vector3.new(vel.X, 0, vel.Z).Magnitude + 0.5)
            if currentSpeed < 1 then currentSpeed = math.floor(h.WalkSpeed) end
            local tagData = speedTags[c]
            if tagData then tagData.Speed.Text = tostring(currentSpeed) end
        end
    end
end)

local lastTime = tick()
local frameCount = 0
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local currentTime = tick()
    if currentTime - lastTime >= 1 then
        local fps = math.floor(frameCount / (currentTime - lastTime) + 0.5)
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
        local tagData = speedTags[LocalPlayer.Character]
        if tagData and tagData.Fps and tagData.Ping then
            tagData.Fps.Text = tostring(fps)
            tagData.Ping.Text = tostring(ping) .. "ms"
        end
        frameCount = 0
        lastTime = currentTime
    end
end)

-- ==========================================
-- External Floating Buttons & Keybind Trigger Handlers
-- ==========================================
local positionsFileName = "SoundHub_ButtonsPositions.json"
local savedPositions = {}
if isfile and readfile and isfile(positionsFileName) then
    pcall(function() savedPositions = HttpService:JSONDecode(readfile(positionsFileName)) or {} end)
end

local function saveAllButtonPositions()
    if writefile then pcall(function() writefile(positionsFileName, HttpService:JSONEncode(savedPositions)) end) end
end

local lockState = true
lockToggleButton.MouseButton1Click:Connect(function()
    if lockState == true then lockState = false; lockToggleButton.Text = "UNLOCK"; lockToggleButton.TextColor3 = Color3.fromRGB(100, 255, 100)
    else lockState = true; lockToggleButton.Text = "LOCK"; lockToggleButton.TextColor3 = Color3.fromRGB(255, 100, 100) end
end)

local buttonList = {"AUTO LEFT", "ANTI DESYNC", "AUTO RIGHT", "TP DOWN", "CARRY SPEED", "DROP BR"}
local defaultBgColor = Color3.fromRGB(8, 8, 8)
local defaultStrokeColor = Color3.fromRGB(30, 30, 30)
local activeBgColor = Color3.fromRGB(30, 20, 45)
local activeStrokeColor = Color3.fromRGB(168, 85, 247)
local activeLoops = {}

for idx, btnText in ipairs(buttonList) do
    local extButton = Instance.new("TextButton")
    extButton.Name = "ExtBtn_" .. btnText:gsub("%s+", "")
    extButton.Size = UDim2.new(0, 56, 0, 56)
    if savedPositions[btnText] then
        local p = savedPositions[btnText]
        extButton.Position = UDim2.new(p.XScale, p.XOffset, p.YScale, p.YOffset)
    else
        local col = (idx - 1) % 3
        local row = math.floor((idx - 1) / 3)
        extButton.Position = UDim2.new(0.72 + (col * 0.07), 0, 0.15 + (row * 0.09), 0)
    end
    extButton.BackgroundColor3 = defaultBgColor
    extButton.Text = btnText
    extButton.TextColor3 = Color3.fromRGB(168, 85, 247)
    extButton.TextSize = 8.5
    extButton.Font = Enum.Font.GothamBold
    extButton.TextWrapped = true
    extButton.Active = true
    extButton.Parent = screenGui
    local extCorner = Instance.new("UICorner"); extCorner.CornerRadius = UDim.new(0, 8); extCorner.Parent = extButton
    local extStroke = Instance.new("UIStroke"); extStroke.Color = defaultStrokeColor; extStroke.Thickness = 1; extStroke.Parent = extButton
    extButtonsMap[btnText] = {Button = extButton, Stroke = extStroke}
    local dragging, dragInput, dragStart, startAbsolutePos
    extButton.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            if lockState == false then
                dragging = true; dragStart = input.Position; startAbsolutePos = extButton.AbsolutePosition
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        savedPositions[btnText] = {
                            XScale = extButton.Position.X.Scale, XOffset = extButton.Position.X.Offset,
                            YScale = extButton.Position.Y.Scale, YOffset = extButton.Position.Y.Offset
                        }
                        saveAllButtonPositions()
                    end
                end)
            end
        end
    end)
    extButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging and dragInput and lockState == false then
            local delta = dragInput.Position - dragStart
            local newAbsolutePos = startAbsolutePos + Vector2.new(delta.X, delta.Y)
            extButton.Position = UDim2.new(0, newAbsolutePos.X, 0, newAbsolutePos.Y)
        end
    end)
    local function triggerAction()
        if btnText == "ANTI DESYNC" then
            if antiDesyncEnabled then stopAntiDesyncAimbot(); extButton.BackgroundColor3 = defaultBgColor; extStroke.Color = defaultStrokeColor
            else startAntiDesyncAimbot(); extButton.BackgroundColor3 = activeBgColor; extStroke.Color = activeStrokeColor end
        elseif btnText == "CARRY SPEED" then
            if activeSpeedMode:find("Carry") then activeSpeedMode = activeSpeedMode:gsub("Carry", ""); extButton.BackgroundColor3 = defaultBgColor; extStroke.Color = defaultStrokeColor
            else activeSpeedMode = activeSpeedMode .. "Carry"; extButton.BackgroundColor3 = activeBgColor; extStroke.Color = activeStrokeColor end
        elseif btnText == "TP DOWN" then
            teleportDown()
            local tweenInfo = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local flashIn = TweenService:Create(extButton, tweenInfo, {BackgroundColor3 = activeBgColor})
            local strokeIn = TweenService:Create(extStroke, tweenInfo, {Color = activeStrokeColor})
            flashIn:Play(); strokeIn:Play()
            task.delay(0.30, function()
                local flashOut = TweenService:Create(extButton, tweenInfo, {BackgroundColor3 = defaultBgColor})
                local strokeOut = TweenService:Create(extStroke, tweenInfo, {Color = defaultStrokeColor})
                flashOut:Play(); strokeOut:Play()
            end)
        elseif btnText == "DROP BR" then
            doDrop()
            local tweenInfo = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local flashIn = TweenService:Create(extButton, tweenInfo, {BackgroundColor3 = activeBgColor})
            local strokeIn = TweenService:Create(extStroke, tweenInfo, {Color = activeStrokeColor})
            flashIn:Play(); strokeIn:Play()
            task.delay(0.30, function()
                local flashOut = TweenService:Create(extButton, tweenInfo, {BackgroundColor3 = defaultBgColor})
                local strokeOut = TweenService:Create(extStroke, tweenInfo, {Color = defaultStrokeColor})
                flashOut:Play(); strokeOut:Play()
            end)
        elseif btnText == "AUTO LEFT" then
            if activeLoops[btnText] then activeLoops[btnText].running = false; activeLoops[btnText] = nil; isAutoLeftActive = false; extButton.BackgroundColor3 = defaultBgColor; extStroke.Color = defaultStrokeColor
            else
                if activeLoops["AUTO RIGHT"] then activeLoops["AUTO RIGHT"].running = false; activeLoops["AUTO RIGHT"] = nil
                    local rightData = extButtonsMap["AUTO RIGHT"]
                    if rightData then rightData.Button.BackgroundColor3 = defaultBgColor; rightData.Stroke.Color = defaultStrokeColor end
                end
                extButton.BackgroundColor3 = activeBgColor; extStroke.Color = activeStrokeColor; isAutoLeftActive = true
                local loopData = {running = true}; activeLoops[btnText] = loopData
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if hrp and humanoid then
                        local pos1 = Vector3.new(-475.3, -5.8, 93.8)
                        local pos2 = Vector3.new(-484.3, -4.8, 98.3)
                        task.spawn(function()
                            while loopData.running do
                                local currentPos = hrp.Position
                                local direction1 = (pos1 - currentPos)
                                if Vector3.new(direction1.X, 0, direction1.Z).Magnitude > 2.0 then
                                    local moveDir1 = Vector3.new(direction1.X, 0, direction1.Z).Unit
                                    local curSpd = getModeBaseSpeed()
                                    humanoid.WalkSpeed = curSpd
                                    hrp.AssemblyLinearVelocity = Vector3.new(moveDir1.X * curSpd, hrp.AssemblyLinearVelocity.Y, moveDir1.Z * curSpd)
                                    RunService.RenderStepped:Wait()
                                else break end
                            end
                            while loopData.running do
                                local currentPos = hrp.Position
                                local direction2 = (pos2 - currentPos)
                                if Vector3.new(direction2.X, 0, direction2.Z).Magnitude > 2.0 then
                                    local moveDir2 = Vector3.new(direction2.X, 0, direction2.Z).Unit
                                    local curSpd = getModeBaseSpeed()
                                    humanoid.WalkSpeed = curSpd
                                    hrp.AssemblyLinearVelocity = Vector3.new(moveDir2.X * curSpd, hrp.AssemblyLinearVelocity.Y, moveDir2.Z * curSpd)
                                    RunService.RenderStepped:Wait()
                                else break end
                            end
                            isAutoLeftActive = false
                            if activeLoops[btnText] == loopData then activeLoops[btnText] = nil; extButton.BackgroundColor3 = defaultBgColor; extStroke.Color = defaultStrokeColor end
                        end)
                    end
                end
            end
        elseif btnText == "AUTO RIGHT" then
            if activeLoops[btnText] then activeLoops[btnText].running = false; activeLoops[btnText] = nil; isAutoLeftActive = false; extButton.BackgroundColor3 = defaultBgColor; extStroke.Color = defaultStrokeColor
            else
                if activeLoops["AUTO LEFT"] then activeLoops["AUTO LEFT"].running = false; activeLoops["AUTO LEFT"] = nil
                    local leftData = extButtonsMap["AUTO LEFT"]
                    if leftData then leftData.Button.BackgroundColor3 = defaultBgColor; leftData.Stroke.Color = defaultStrokeColor end
                end
                extButton.BackgroundColor3 = activeBgColor; extStroke.Color = activeStrokeColor; isAutoLeftActive = true
                local loopData = {running = true}; activeLoops[btnText] = loopData
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if hrp and humanoid then
                        local pos1 = Vector3.new(-476.8, -6.2, 25.6)
                        local pos2 = Vector3.new(-482.6, -5.1, 25.5)
                        task.spawn(function()
                            while loopData.running do
                                local currentPos = hrp.Position
                                local direction1 = (pos1 - currentPos)
                                if Vector3.new(direction1.X, 0, direction1.Z).Magnitude > 2.0 then
                                    local moveDir1 = Vector3.new(direction1.X, 0, direction1.Z).Unit
                                    local curSpd = getModeBaseSpeed()
                                    humanoid.WalkSpeed = curSpd
                                    hrp.AssemblyLinearVelocity = Vector3.new(moveDir1.X * curSpd, hrp.AssemblyLinearVelocity.Y, moveDir1.Z * curSpd)
                                    RunService.RenderStepped:Wait()
                                else break end
                            end
                            while loopData.running do
                                local currentPos = hrp.Position
                                local direction2 = (pos2 - currentPos)
                                if Vector3.new(direction2.X, 0, direction2.Z).Magnitude > 2.0 then
                                    local moveDir2 = Vector3.new(direction2.X, 0, direction2.Z).Unit
                                    local curSpd = getModeBaseSpeed()
                                    humanoid.WalkSpeed = curSpd
                                    hrp.AssemblyLinearVelocity = Vector3.new(moveDir2.X * curSpd, hrp.AssemblyLinearVelocity.Y, moveDir2.Z * curSpd)
                                    RunService.RenderStepped:Wait()
                                else break end
                            end
                            isAutoLeftActive = false
                            if activeLoops[btnText] == loopData then activeLoops[btnText] = nil; extButton.BackgroundColor3 = defaultBgColor; extStroke.Color = defaultStrokeColor end
                        end)
                    end
                end
            end
        end
    end
    extButton.MouseButton1Click:Connect(function() if lockState == false then return end; triggerAction() end)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        for name, key in pairs(KeybindsData) do
            if key and input.KeyCode == key then
                if name == "nrml spd" then activeSpeedMode = "Normal"
                elseif name == "lagger spd" then activeSpeedMode = "Lagger"
                elseif name == "extra spd" then activeSpeedMode = "Extra"
                elseif name == "tp down" then teleportDown()
                elseif name == "dropt br" then doDrop()
                elseif name == "gui" then
                    if mainFrame.Visible then mainFrame.Visible = false else mainFrame.Visible = true end
                end
            end
        end
    end
end)

-- ==========================================
-- Group Frame for Normal, Lagger, Extra
-- ==========================================
local groupPositionsFileName = "SoundHub_ModeGroupPosition.json"
local savedGroupPos = {}
if isfile and readfile and isfile(groupPositionsFileName) then
    pcall(function() savedGroupPos = HttpService:JSONDecode(readfile(groupPositionsFileName)) or {} end)
end

local groupFrame = Instance.new("Frame")
groupFrame.Name = "ModeGroupFrame"
groupFrame.Size = UDim2.new(0, 180, 0, 40)
if savedGroupPos.XScale then groupFrame.Position = UDim2.new(savedGroupPos.XScale, savedGroupPos.XOffset, savedGroupPos.YScale, savedGroupPos.YOffset)
else groupFrame.Position = UDim2.new(0.5, -90, 0.85, 0) end
groupFrame.BackgroundTransparency = 1
groupFrame.Active = true
groupFrame.Parent = screenGui

local groupLayout = Instance.new("UIListLayout")
groupLayout.FillDirection = Enum.FillDirection.Horizontal
groupLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
groupLayout.VerticalAlignment = Enum.VerticalAlignment.Center
groupLayout.SortOrder = Enum.SortOrder.LayoutOrder
groupLayout.Padding = UDim.new(0, 8)
groupLayout.Parent = groupFrame

local modeButtonsList = {"Normal", "Lagger", "Extra"}
local modeButtonsObjects = {}
local activeExternalButton = nil

for _, btnText in ipairs(modeButtonsList) do
    local extButton = Instance.new("TextButton")
    extButton.Name = "ExtBtn_" .. btnText
    extButton.Size = UDim2.new(0, 54, 0, 36)
    extButton.BackgroundColor3 = defaultBgColor
    extButton.Text = btnText
    extButton.TextColor3 = Color3.fromRGB(168, 85, 247)
    extButton.TextSize = 9.5
    extButton.Font = Enum.Font.GothamBold
    extButton.Parent = groupFrame
    local extCorner = Instance.new("UICorner"); extCorner.CornerRadius = UDim.new(0, 6); extCorner.Parent = extButton
    local extStroke = Instance.new("UIStroke"); extStroke.Color = defaultStrokeColor; extStroke.Thickness = 1; extStroke.Parent = extButton
    modeButtonsObjects[btnText] = {Button = extButton, Stroke = extStroke}
    extButton.MouseButton1Click:Connect(function()
        if lockState == false then return end
        if activeExternalButton == extButton then return end
        if activeExternalButton then activeExternalButton.BackgroundColor3 = defaultBgColor
            local prevStroke = activeExternalButton:FindFirstChildOfClass("UIStroke")
            if prevStroke then prevStroke.Color = defaultStrokeColor end
        end
        extButton.BackgroundColor3 = activeBgColor; extStroke.Color = activeStrokeColor; activeExternalButton = extButton
        if activeSpeedMode:find("Carry") then activeSpeedMode = btnText .. "Carry" else activeSpeedMode = btnText end
    end)
end

if modeButtonsObjects["Normal"] then
    local normObj = modeButtonsObjects["Normal"]
    normObj.Button.BackgroundColor3 = activeBgColor; normObj.Stroke.Color = activeStrokeColor
    activeExternalButton = normObj.Button; activeSpeedMode = "Normal"
end

local groupDragging, groupDragInput, groupDragStart, groupStartAbsolutePos
groupFrame.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        if lockState == false then
            groupDragging = true; groupDragStart = input.Position; groupStartAbsolutePos = groupFrame.AbsolutePosition
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    groupDragging = false
                    savedGroupPos = { XScale = groupFrame.Position.X.Scale, XOffset = groupFrame.Position.X.Offset, YScale = groupFrame.Position.Y.Scale, YOffset = groupFrame.Position.Y.Offset }
                    if writefile then pcall(function() writefile(groupPositionsFileName, HttpService:JSONEncode(savedGroupPos)) end) end
                end
            end)
        end
    end
end)
groupFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then groupDragInput = input end
end)
RunService.RenderStepped:Connect(function()
    if groupDragging and groupDragInput and lockState == false then
        local delta = groupDragInput.Position - groupDragStart
        local newAbsolutePos = groupStartAbsolutePos + Vector2.new(delta.X, delta.Y)
        groupFrame.Position = UDim2.new(0, newAbsolutePos.X, 0, newAbsolutePos.Y)
    end
end)

-- ==========================================
-- VISUALS TAB
-- ==========================================
local function createVisualsToggle(titleText, defaultState, onToggleCallback)
    local boxFrame = Instance.new("Frame"); boxFrame.Size = UDim2.new(1, 0, 0, 24)
    boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12); boxFrame.Parent = visualsPage
    local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = boxFrame
    local boxStroke = Instance.new("UIStroke"); boxStroke.Color = Color3.fromRGB(30, 30, 30); boxStroke.Thickness = 1; boxStroke.Parent = boxFrame
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.6, 0, 1, 0); label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1; label.Text = titleText; label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 8; label.Font = Enum.Font.GothamBold; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = boxFrame
    local toggleBtn = Instance.new("TextButton"); toggleBtn.Size = UDim2.new(0, 32, 0, 16); toggleBtn.Position = UDim2.new(1, -40, 0.5, -8)
    toggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(25, 25, 30)
    toggleBtn.Text = ""; toggleBtn.Parent = boxFrame
    local toggleBtnCorner = Instance.new("UICorner"); toggleBtnCorner.CornerRadius = UDim.new(1, 0); toggleBtnCorner.Parent = toggleBtn
    local circle = Instance.new("Frame"); circle.Size = UDim2.new(0, 12, 0, 12)
    circle.Position = defaultState and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255); circle.Parent = toggleBtn
    local circleCorner = Instance.new("UICorner"); circleCorner.CornerRadius = UDim.new(1, 0); circleCorner.Parent = circle
    local currentState = defaultState
    toggleBtn.MouseButton1Click:Connect(function()
        currentState = not currentState
        if currentState then
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(168, 85, 247)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(1, -14, 0.5, -6)}):Play()
        else
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 30)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -6)}):Play()
        end
        onToggleCallback(currentState)
    end)
    return toggleBtn
end

local function createVisualsDropdown(titleText, options, defaultOption, onSelectCallback)
    local boxFrame = Instance.new("Frame"); boxFrame.Size = UDim2.new(1, 0, 0, 28)
    boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12); boxFrame.Parent = visualsPage
    local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = boxFrame
    local boxStroke = Instance.new("UIStroke"); boxStroke.Color = Color3.fromRGB(30, 30, 30); boxStroke.Thickness = 1; boxStroke.Parent = boxFrame
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.5, 0, 1, 0); label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1; label.Text = titleText; label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 8; label.Font = Enum.Font.GothamBold; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = boxFrame
    local dropdownBtn = Instance.new("TextButton"); dropdownBtn.Size = UDim2.new(0, 80, 0, 20); dropdownBtn.Position = UDim2.new(1, -88, 0.5, -10)
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22); dropdownBtn.Text = defaultOption or options[1]
    dropdownBtn.TextColor3 = Color3.fromRGB(168, 85, 247); dropdownBtn.TextSize = 8; dropdownBtn.Font = Enum.Font.GothamBold; dropdownBtn.Parent = boxFrame
    local dCorner = Instance.new("UICorner"); dCorner.CornerRadius = UDim.new(0, 3); dCorner.Parent = dropdownBtn
    local dStroke = Instance.new("UIStroke"); dStroke.Color = Color3.fromRGB(168, 85, 247); dStroke.Transparency = 0.5; dStroke.Thickness = 1; dStroke.Parent = dropdownBtn
    local isOpen = false; local dropdownList = nil
    dropdownBtn.MouseButton1Click:Connect(function()
        if isOpen then if dropdownList then dropdownList:Destroy() end; isOpen = false; return end
        isOpen = true
        dropdownList = Instance.new("Frame"); dropdownList.Size = UDim2.new(0, 80, 0, #options * 18); dropdownList.Position = UDim2.new(1, -88, 0, 28)
        dropdownList.BackgroundColor3 = Color3.fromRGB(12, 12, 12); dropdownList.ZIndex = 10; dropdownList.Parent = boxFrame
        local listCorner = Instance.new("UICorner"); listCorner.CornerRadius = UDim.new(0, 4); listCorner.Parent = dropdownList
        local listStroke = Instance.new("UIStroke"); listStroke.Color = Color3.fromRGB(30, 30, 30); listStroke.Thickness = 1; listStroke.Parent = dropdownList
        local listLayout = Instance.new("UIListLayout"); listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.Padding = UDim.new(0, 0); listLayout.Parent = dropdownList
        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton"); optBtn.Size = UDim2.new(1, 0, 0, 18)
            optBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22); optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(200, 200, 200); optBtn.TextSize = 7.5; optBtn.Font = Enum.Font.GothamBold; optBtn.Parent = dropdownList
            optBtn.MouseButton1Click:Connect(function()
                dropdownBtn.Text = opt; onSelectCallback(opt)
                if dropdownList then dropdownList:Destroy() end; isOpen = false
            end)
        end
    end)
    return dropdownBtn
end

local function createVisualsSlider(titleText, minVal, maxVal, defaultVal, step, onValueChange)
    local boxFrame = Instance.new("Frame"); boxFrame.Size = UDim2.new(1, 0, 0, 32)
    boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12); boxFrame.Parent = visualsPage
    local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = boxFrame
    local boxStroke = Instance.new("UIStroke"); boxStroke.Color = Color3.fromRGB(30, 30, 30); boxStroke.Thickness = 1; boxStroke.Parent = boxFrame
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.45, 0, 0, 12); label.Position = UDim2.new(0, 8, 0, 2)
    label.BackgroundTransparency = 1; label.Text = titleText; label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 8; label.Font = Enum.Font.GothamBold; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = boxFrame
    local valueLabel = Instance.new("TextLabel"); valueLabel.Size = UDim2.new(0, 30, 0, 12); valueLabel.Position = UDim2.new(1, -38, 0, 2)
    valueLabel.BackgroundTransparency = 1; valueLabel.Text = tostring(defaultVal); valueLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
    valueLabel.TextSize = 8; valueLabel.Font = Enum.Font.GothamBold; valueLabel.TextXAlignment = Enum.TextXAlignment.Right; valueLabel.Parent = boxFrame
    local sliderBar = Instance.new("Frame"); sliderBar.Size = UDim2.new(0.45, 0, 0, 4); sliderBar.Position = UDim2.new(0, 8, 0, 20)
    sliderBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30); sliderBar.Parent = boxFrame
    local barCorner = Instance.new("UICorner"); barCorner.CornerRadius = UDim.new(1, 0); barCorner.Parent = sliderBar
    local fillBar = Instance.new("Frame"); local fillPercent = (defaultVal - minVal) / (maxVal - minVal)
    fillBar.Size = UDim2.new(fillPercent, 0, 1, 0); fillBar.BackgroundColor3 = Color3.fromRGB(168, 85, 247); fillBar.Parent = sliderBar
    local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(1, 0); fillCorner.Parent = fillBar
    local sliderBtn = Instance.new("TextButton"); sliderBtn.Size = UDim2.new(0, 14, 0, 14)
    sliderBtn.Position = UDim2.new(fillPercent, -7, 0.5, -7); sliderBtn.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    sliderBtn.Text = ""; sliderBtn.Parent = sliderBar
    local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(1, 0); btnCorner.Parent = sliderBtn
    local dragging = false; local currentValue = defaultVal
    local function updateSlider(posX)
        local barSize = sliderBar.AbsoluteSize.X
        if barSize <= 0 then return end
        local percent = math.clamp((posX - sliderBar.AbsolutePosition.X) / barSize, 0, 1)
        local newVal = math.round((minVal + percent * (maxVal - minVal)) / step) * step
        newVal = math.clamp(newVal, minVal, maxVal); currentValue = newVal
        valueLabel.Text = tostring(newVal); fillBar.Size = UDim2.new(percent, 0, 1, 0)
        sliderBtn.Position = UDim2.new(percent, -7, 0.5, -7); onValueChange(newVal)
    end
    sliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; updateSlider(input.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateSlider(input.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then dragging = false end
    end)
    return sliderBtn
end

-- BUILD VISUALS PAGE UI
local visualsHeader1 = Instance.new("TextLabel"); visualsHeader1.Size = UDim2.new(1, 0, 0, 18)
visualsHeader1.BackgroundTransparency = 1; visualsHeader1.Text = "• SKY & ENVIRONMENT"
visualsHeader1.TextColor3 = Color3.fromRGB(168, 85, 247); visualsHeader1.TextSize = 8
visualsHeader1.Font = Enum.Font.GothamBold; visualsHeader1.TextXAlignment = Enum.TextXAlignment.Left; visualsHeader1.Parent = visualsPage

createVisualsDropdown("Sky Theme", {"Off", "Night", "Day", "Cosmic", "Sunset", "Aurora"}, "Off", function(selected)
    if selected == "Off" then Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = true
        Lighting.Ambient = Color3.fromRGB(127, 127, 127); Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        for _, v in ipairs(Lighting:GetChildren()) do if v:IsA("Sky") or v:IsA("Atmosphere") then v:Destroy() end end
    elseif selected == "Night" then Lighting.Brightness = 1.5; Lighting.ClockTime = 22
        Lighting.Ambient = Color3.fromRGB(80, 70, 100); Lighting.OutdoorAmbient = Color3.fromRGB(60, 50, 80)
        local sky = Instance.new("Sky"); sky.Parent = Lighting
        local atm = Instance.new("Atmosphere"); atm.Density = 0.4; atm.Color = Color3.fromRGB(120, 80, 180); atm.Decay = Color3.fromRGB(100, 50, 150); atm.Parent = Lighting
    elseif selected == "Day" then Lighting.Brightness = 3; Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(200, 200, 200); Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        for _, v in ipairs(Lighting:GetChildren()) do if v:IsA("Sky") or v:IsA("Atmosphere") then v:Destroy() end end
    elseif selected == "Cosmic" then Lighting.Brightness = 1.2; Lighting.ClockTime = 0
        Lighting.Ambient = Color3.fromRGB(50, 40, 80); Lighting.OutdoorAmbient = Color3.fromRGB(40, 30, 70)
        local sky = Instance.new("Sky"); sky.StarCount = 10000; sky.Parent = Lighting
        local atm = Instance.new("Atmosphere"); atm.Density = 0.2; atm.Color = Color3.fromRGB(80, 60, 150); atm.Decay = Color3.fromRGB(60, 40, 120); atm.Parent = Lighting
    elseif selected == "Sunset" then Lighting.Brightness = 2.5; Lighting.ClockTime = 17.5
        Lighting.Ambient = Color3.fromRGB(180, 120, 80); Lighting.OutdoorAmbient = Color3.fromRGB(200, 140, 100)
        local sky = Instance.new("Sky"); sky.Parent = Lighting
        local atm = Instance.new("Atmosphere"); atm.Density = 0.4; atm.Color = Color3.fromRGB(255, 150, 80); atm.Decay = Color3.fromRGB(200, 100, 50); atm.Parent = Lighting
    elseif selected == "Aurora" then Lighting.Brightness = 2.8; Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(150, 120, 200); Lighting.OutdoorAmbient = Color3.fromRGB(160, 130, 210)
        local sky = Instance.new("Sky"); sky.Parent = Lighting
        local atm = Instance.new("Atmosphere"); atm.Density = 0.5; atm.Color = Color3.fromRGB(100, 200, 255); atm.Decay = Color3.fromRGB(80, 150, 255); atm.Glare = 2; atm.Haze = 2; atm.Parent = Lighting
    end
end)

createVisualsSlider("Time", 0, 24, 14, 1, function(value) Lighting.ClockTime = value end)
createVisualsSlider("Brightness", 0.1, 5, 2, 0.1, function(value) Lighting.Brightness = value end)

local visualsHeader2 = Instance.new("TextLabel"); visualsHeader2.Size = UDim2.new(1, 0, 0, 18)
visualsHeader2.BackgroundTransparency = 1; visualsHeader2.Text = "• ESP & VISUALS"
visualsHeader2.TextColor3 = Color3.fromRGB(168, 85, 247); visualsHeader2.TextSize = 8
visualsHeader2.Font = Enum.Font.GothamBold; visualsHeader2.TextXAlignment = Enum.TextXAlignment.Left; visualsHeader2.Parent = visualsPage

createVisualsToggle("ESP Boxes", false, function(state) end)
createVisualsToggle("Player Chams", false, function(state) end)
createVisualsToggle("Fullbright", false, function(state)
    if state then Lighting.Brightness = 5; Lighting.Ambient = Color3.fromRGB(255, 255, 255); Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255); Lighting.GlobalShadows = false
    else Lighting.Brightness = 2; Lighting.Ambient = Color3.fromRGB(127, 127, 127); Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127); Lighting.GlobalShadows = true end
end)

local visualsHeader3 = Instance.new("TextLabel"); visualsHeader3.Size = UDim2.new(1, 0, 0, 18)
visualsHeader3.BackgroundTransparency = 1; visualsHeader3.Text = "• WORLD CUSTOMIZATION"
visualsHeader3.TextColor3 = Color3.fromRGB(168, 85, 247); visualsHeader3.TextSize = 8
visualsHeader3.Font = Enum.Font.GothamBold; visualsHeader3.TextXAlignment = Enum.TextXAlignment.Left; visualsHeader3.Parent = visualsPage

createVisualsDropdown("Fog Color", {"Off", "White", "Black", "Purple", "Blood"}, "Off", function(selected)
    if selected == "Off" then Lighting.FogEnd = 100000; Lighting.FogStart = 0; Lighting.FogColor = Color3.fromRGB(191, 191, 191)
    elseif selected == "White" then Lighting.FogEnd = 50; Lighting.FogStart = 1; Lighting.FogColor = Color3.fromRGB(255, 255, 255)
    elseif selected == "Black" then Lighting.FogEnd = 50; Lighting.FogStart = 1; Lighting.FogColor = Color3.fromRGB(0, 0, 0)
    elseif selected == "Purple" then Lighting.FogEnd = 50; Lighting.FogStart = 1; Lighting.FogColor = Color3.fromRGB(168, 85, 247)
    elseif selected == "Blood" then Lighting.FogEnd = 50; Lighting.FogStart = 1; Lighting.FogColor = Color3.fromRGB(255, 0, 0) end
end)

createVisualsToggle("Bloom Effect", false, function(state) end)
createVisualsToggle("Sun Rays", false, function(state) end)

local visualsHeader4 = Instance.new("TextLabel"); visualsHeader4.Size = UDim2.new(1, 0, 0, 18)
visualsHeader4.BackgroundTransparency = 1; visualsHeader4.Text = "• CAMERA SETTINGS"
visualsHeader4.TextColor3 = Color3.fromRGB(168, 85, 247); visualsHeader4.TextSize = 8
visualsHeader4.Font = Enum.Font.GothamBold; visualsHeader4.TextXAlignment = Enum.TextXAlignment.Left; visualsHeader4.Parent = visualsPage

createVisualsSlider("FOV", 30, 120, 70, 5, function(value) Camera.FieldOfView = value end)
createVisualsToggle("Freecam", false, function(state) end)

local visualsHeader5 = Instance.new("TextLabel"); visualsHeader5.Size = UDim2.new(1, 0, 0, 18)
visualsHeader5.BackgroundTransparency = 1; visualsHeader5.Text = "• RENDER SETTINGS"
visualsHeader5.TextColor3 = Color3.fromRGB(168, 85, 247); visualsHeader5.TextSize = 8
visualsHeader5.Font = Enum.Font.GothamBold; visualsHeader5.TextXAlignment = Enum.TextXAlignment.Left; visualsHeader5.Parent = visualsPage

createVisualsToggle("Wireframe Mode", false, function(state) end)
createVisualsToggle("Low GFX Mode", false, function(state)
    if state then settings().Rendering.QualityLevel = Enum.QualityLevel.Level01; settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01; Lighting.GlobalShadows = false; Lighting.Brightness = 1.5
    else settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic; settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Automatic; Lighting.GlobalShadows = true; Lighting.Brightness = 2 end
end)
createVisualsToggle("Hide Map Decor", false, function(state) end)

local visualsHeader6 = Instance.new("TextLabel"); visualsHeader6.Size = UDim2.new(1, 0, 0, 18)
visualsHeader6.BackgroundTransparency = 1; visualsHeader6.Text = "• PLAYER VISUALS"
visualsHeader6.TextColor3 = Color3.fromRGB(168, 85, 247); visualsHeader6.TextSize = 8
visualsHeader6.Font = Enum.Font.GothamBold; visualsHeader6.TextXAlignment = Enum.TextXAlignment.Left; visualsHeader6.Parent = visualsPage

createVisualsToggle("Nametags", false, function(state) end)
createVisualsToggle("Health Bars", false, function(state) end)
createVisualsToggle("Distance Tags", false, function(state) end)

-- ==========================================
-- SETTINGS PAGE UI
-- ==========================================
task.defer(function()
    if not settingsPage then return end
    local function createSettingsToggle(titleText, defaultState, onToggleCallback)
        local boxFrame = Instance.new("Frame"); boxFrame.Size = UDim2.new(1, 0, 0, 24)
        boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12); boxFrame.Parent = settingsPage
        local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = boxFrame
        local boxStroke = Instance.new("UIStroke"); boxStroke.Color = Color3.fromRGB(30, 30, 30); boxStroke.Thickness = 1; boxStroke.Parent = boxFrame
        local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.6, 0, 1, 0); label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1; label.Text = titleText; label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.TextSize = 8; label.Font = Enum.Font.GothamBold; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = boxFrame
        local toggleBtn = Instance.new("TextButton"); toggleBtn.Size = UDim2.new(0, 32, 0, 16); toggleBtn.Position = UDim2.new(1, -40, 0.5, -8)
        toggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(25, 25, 30)
        toggleBtn.Text = ""; toggleBtn.Parent = boxFrame
        local toggleBtnCorner = Instance.new("UICorner"); toggleBtnCorner.CornerRadius = UDim.new(1, 0); toggleBtnCorner.Parent = toggleBtn
        local circle = Instance.new("Frame"); circle.Size = UDim2.new(0, 12, 0, 12)
        circle.Position = defaultState and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255); circle.Parent = toggleBtn
        local circleCorner = Instance.new("UICorner"); circleCorner.CornerRadius = UDim.new(1, 0); circleCorner.Parent = circle
        local currentState = defaultState
        toggleBtn.MouseButton1Click:Connect(function()
            currentState = not currentState
            if currentState then
                TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(168, 85, 247)}):Play()
                TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(1, -14, 0.5, -6)}):Play()
            else
                TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 30)}):Play()
                TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -6)}):Play()
            end
            onToggleCallback(currentState)
        end)
        return toggleBtn
    end
    local function createSettingsDropdown(titleText, options, defaultOption, onSelectCallback)
        local boxFrame = Instance.new("Frame"); boxFrame.Size = UDim2.new(1, 0, 0, 28)
        boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12); boxFrame.Parent = settingsPage
        local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = boxFrame
        local boxStroke = Instance.new("UIStroke"); boxStroke.Color = Color3.fromRGB(30, 30, 30); boxStroke.Thickness = 1; boxStroke.Parent = boxFrame
        local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.5, 0, 1, 0); label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1; label.Text = titleText; label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.TextSize = 8; label.Font = Enum.Font.GothamBold; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = boxFrame
        local dropdownBtn = Instance.new("TextButton"); dropdownBtn.Size = UDim2.new(0, 80, 0, 20); dropdownBtn.Position = UDim2.new(1, -88, 0.5, -10)
        dropdownBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22); dropdownBtn.Text = defaultOption or options[1]
        dropdownBtn.TextColor3 = Color3.fromRGB(168, 85, 247); dropdownBtn.TextSize = 8; dropdownBtn.Font = Enum.Font.GothamBold; dropdownBtn.Parent = boxFrame
        local dCorner = Instance.new("UICorner"); dCorner.CornerRadius = UDim.new(0, 3); dCorner.Parent = dropdownBtn
        local dStroke = Instance.new("UIStroke"); dStroke.Color = Color3.fromRGB(168, 85, 247); dStroke.Transparency = 0.5; dStroke.Thickness = 1; dStroke.Parent = dropdownBtn
        local isOpen = false; local dropdownList = nil
        dropdownBtn.MouseButton1Click:Connect(function()
            if isOpen then if dropdownList then dropdownList:Destroy() end; isOpen = false; return end
            isOpen = true
            dropdownList = Instance.new("Frame"); dropdownList.Size = UDim2.new(0, 80, 0, #options * 18); dropdownList.Position = UDim2.new(1, -88, 0, 28)
            dropdownList.BackgroundColor3 = Color3.fromRGB(12, 12, 12); dropdownList.ZIndex = 10; dropdownList.Parent = boxFrame
            local listCorner = Instance.new("UICorner"); listCorner.CornerRadius = UDim.new(0, 4); listCorner.Parent = dropdownList
            local listStroke = Instance.new("UIStroke"); listStroke.Color = Color3.fromRGB(30, 30, 30); listStroke.Thickness = 1; listStroke.Parent = dropdownList
            local listLayout = Instance.new("UIListLayout"); listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.Padding = UDim.new(0, 0); listLayout.Parent = dropdownList
            for _, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton"); optBtn.Size = UDim2.new(1, 0, 0, 18)
                optBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22); optBtn.Text = opt
                optBtn.TextColor3 = Color3.fromRGB(200, 200, 200); optBtn.TextSize = 7.5; optBtn.Font = Enum.Font.GothamBold; optBtn.Parent = dropdownList
                optBtn.MouseButton1Click:Connect(function()
                    dropdownBtn.Text = opt; onSelectCallback(opt)
                    if dropdownList then dropdownList:Destroy() end; isOpen = false
                end)
            end
        end)
        return dropdownBtn
    end
    local function createSettingsSlider(titleText, minVal, maxVal, defaultVal, step, onValueChange)
        local boxFrame = Instance.new("Frame"); boxFrame.Size = UDim2.new(1, 0, 0, 32)
        boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12); boxFrame.Parent = settingsPage
        local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = boxFrame
        local boxStroke = Instance.new("UIStroke"); boxStroke.Color = Color3.fromRGB(30, 30, 30); boxStroke.Thickness = 1; boxStroke.Parent = boxFrame
        local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.45, 0, 0, 12); label.Position = UDim2.new(0, 8, 0, 2)
        label.BackgroundTransparency = 1; label.Text = titleText; label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.TextSize = 8; label.Font = Enum.Font.GothamBold; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = boxFrame
        local valueLabel = Instance.new("TextLabel"); valueLabel.Size = UDim2.new(0, 30, 0, 12); valueLabel.Position = UDim2.new(1, -38, 0, 2)
        valueLabel.BackgroundTransparency = 1; valueLabel.Text = tostring(defaultVal); valueLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
        valueLabel.TextSize = 8; valueLabel.Font = Enum.Font.GothamBold; valueLabel.TextXAlignment = Enum.TextXAlignment.Right; valueLabel.Parent = boxFrame
        local sliderBar = Instance.new("Frame"); sliderBar.Size = UDim2.new(0.45, 0, 0, 4); sliderBar.Position = UDim2.new(0, 8, 0, 20)
        sliderBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30); sliderBar.Parent = boxFrame
        local barCorner = Instance.new("UICorner"); barCorner.CornerRadius = UDim.new(1, 0); barCorner.Parent = sliderBar
        local fillBar = Instance.new("Frame"); local fillPercent = (defaultVal - minVal) / (maxVal - minVal)
        fillBar.Size = UDim2.new(fillPercent, 0, 1, 0); fillBar.BackgroundColor3 = Color3.fromRGB(168, 85, 247); fillBar.Parent = sliderBar
        local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(1, 0); fillCorner.Parent = fillBar
        local sliderBtn = Instance.new("TextButton"); sliderBtn.Size = UDim2.new(0, 14, 0, 14)
        sliderBtn.Position = UDim2.new(fillPercent, -7, 0.5, -7); sliderBtn.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
        sliderBtn.Text = ""; sliderBtn.Parent = sliderBar
        local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(1, 0); btnCorner.Parent = sliderBtn
        local dragging = false; local currentValue = defaultVal
        local function updateSlider(posX)
            local barSize = sliderBar.AbsoluteSize.X
            if barSize <= 0 then return end
            local percent = math.clamp((posX - sliderBar.AbsolutePosition.X) / barSize, 0, 1)
            local newVal = math.round((minVal + percent * (maxVal - minVal)) / step) * step
            newVal = math.clamp(newVal, minVal, maxVal); currentValue = newVal
            valueLabel.Text = tostring(newVal); fillBar.Size = UDim2.new(percent, 0, 1, 0)
            sliderBtn.Position = UDim2.new(percent, -7, 0.5, -7); onValueChange(newVal)
        end
        sliderBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; updateSlider(input.Position.X) end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateSlider(input.Position.X) end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then dragging = false end
        end)
        return sliderBtn
    end
    local function createSettingsButton(titleText, callback)
        local boxFrame = Instance.new("Frame"); boxFrame.Size = UDim2.new(1, 0, 0, 30)
        boxFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12); boxFrame.Parent = settingsPage
        local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = boxFrame
        local boxStroke = Instance.new("UIStroke"); boxStroke.Color = Color3.fromRGB(30, 30, 30); boxStroke.Thickness = 1; boxStroke.Parent = boxFrame
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0.8, 0, 0, 20); btn.Position = UDim2.new(0.5, -0.4, 0.5, -10)
        btn.BackgroundColor3 = Color3.fromRGB(168, 85, 247); btn.Text = titleText
        btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 8; btn.Font = Enum.Font.GothamBold; btn.Parent = boxFrame
        local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(0, 4); btnCorner.Parent = btn
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    local settingsHeader = Instance.new("TextLabel"); settingsHeader.Size = UDim2.new(1, 0, 0, 18)
    settingsHeader.BackgroundTransparency = 1; settingsHeader.Text = "• VISUAL SETTINGS"
    settingsHeader.TextColor3 = Color3.fromRGB(168, 85, 247); settingsHeader.TextSize = 8
    settingsHeader.Font = Enum.Font.GothamBold; settingsHeader.TextXAlignment = Enum.TextXAlignment.Left; settingsHeader.Parent = settingsPage

    createSettingsDropdown("Sky Theme", {"Off", "Night", "Day", "Cosmic", "Sunset", "Aurora"}, "Off", function(selected)
        if selected == "Off" then Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = true
            Lighting.Ambient = Color3.fromRGB(127, 127, 127); Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
            for _, v in ipairs(Lighting:GetChildren()) do if v:IsA("Sky") or v:IsA("Atmosphere") then v:Destroy() end end
        elseif selected == "Night" then Lighting.Brightness = 1.5; Lighting.ClockTime = 22
            Lighting.Ambient = Color3.fromRGB(80, 70, 100); Lighting.OutdoorAmbient = Color3.fromRGB(60, 50, 80)
            local sky = Instance.new("Sky"); sky.Parent = Lighting
            local atm = Instance.new("Atmosphere"); atm.Density = 0.4; atm.Color = Color3.fromRGB(120, 80, 180); atm.Decay = Color3.fromRGB(100, 50, 150); atm.Parent = Lighting
        elseif selected == "Day" then Lighting.Brightness = 3; Lighting.ClockTime = 14
            Lighting.Ambient = Color3.fromRGB(200, 200, 200); Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
            for _, v in ipairs(Lighting:GetChildren()) do if v:IsA("Sky") or v:IsA("Atmosphere") then v:Destroy() end end
        elseif selected == "Cosmic" then Lighting.Brightness = 1.2; Lighting.ClockTime = 0
            Lighting.Ambient = Color3.fromRGB(50, 40, 80); Lighting.OutdoorAmbient = Color3.fromRGB(40, 30, 70)
            local sky = Instance.new("Sky"); sky.StarCount = 10000; sky.Parent = Lighting
            local atm = Instance.new("Atmosphere"); atm.Density = 0.2; atm.Color = Color3.fromRGB(80, 60, 150); atm.Decay = Color3.fromRGB(60, 40, 120); atm.Parent = Lighting
        elseif selected == "Sunset" then Lighting.Brightness = 2.5; Lighting.ClockTime = 17.5
            Lighting.Ambient = Color3.fromRGB(180, 120, 80); Lighting.OutdoorAmbient = Color3.fromRGB(200, 140, 100)
            local sky = Instance.new("Sky"); sky.Parent = Lighting
            local atm = Instance.new("Atmosphere"); atm.Density = 0.4; atm.Color = Color3.fromRGB(255, 150, 80); atm.Decay = Color3.fromRGB(200, 100, 50); atm.Parent = Lighting
        elseif selected == "Aurora" then Lighting.Brightness = 2.8; Lighting.ClockTime = 14
            Lighting.Ambient = Color3.fromRGB(150, 120, 200); Lighting.OutdoorAmbient = Color3.fromRGB(160, 130, 210)
            local sky = Instance.new("Sky"); sky.Parent = Lighting
            local atm = Instance.new("Atmosphere"); atm.Density = 0.5; atm.Color = Color3.fromRGB(100, 200, 255); atm.Decay = Color3.fromRGB(80, 150, 255); atm.Glare = 2; atm.Haze = 2; atm.Parent = Lighting
        end
    end)

    createSettingsSlider("GUI Scale", 0.4, 0.8, 0.6, 0.01, function(value)
        if screenGui then local scale = Instance.new("UIScale"); scale.Scale = value; scale.Parent = mainFrame end
    end)

    createSettingsToggle("FPS Boost", false, function(state)
        if state then if setfpscap then setfpscap(999) end else if setfpscap then setfpscap(60) end end
    end)

    createSettingsToggle("Anti-Lag Visuals", false, function(state)
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") then if state then part.Material = Enum.Material.SmoothPlastic end end
        end
    end)

    createSettingsToggle("Nuke Optimiser", false, function(state)
        if state then settings().Rendering.QualityLevel = Enum.QualityLevel.Level01; settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01; Lighting.GlobalShadows = false
        else settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic; settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Automatic; Lighting.GlobalShadows = true end
    end)

    local settingsHeader2 = Instance.new("TextLabel"); settingsHeader2.Size = UDim2.new(1, 0, 0, 18)
    settingsHeader2.BackgroundTransparency = 1; settingsHeader2.Text = "• AUDIO SETTINGS"
    settingsHeader2.TextColor3 = Color3.fromRGB(168, 85, 247); settingsHeader2.TextSize = 8
    settingsHeader2.Font = Enum.Font.GothamBold; settingsHeader2.TextXAlignment = Enum.TextXAlignment.Left; settingsHeader2.Parent = settingsPage

    createSettingsDropdown("Intro Music", {"Off", "Song 1", "Song 2", "Song 3"}, "Song 1", function(selected) end)
    createSettingsToggle("Enable Intro Sound", true, function(state) end)

    local settingsHeader3 = Instance.new("TextLabel"); settingsHeader3.Size = UDim2.new(1, 0, 0, 18)
    settingsHeader3.BackgroundTransparency = 1; settingsHeader3.Text = "• CONFIG MANAGEMENT"
    settingsHeader3.TextColor3 = Color3.fromRGB(168, 85, 247); settingsHeader3.TextSize = 8
    settingsHeader3.Font = Enum.Font.GothamBold; settingsHeader3.TextXAlignment = Enum.TextXAlignment.Left; settingsHeader3.Parent = settingsPage

    createSettingsButton("Save Config", function() saveAllSettings(); print("Config Saved Successfully!") end)
    createSettingsButton("Reset Config", function()
        normalSpeedValue = 50; carrySpeedValue = 37; laggerSpeedValue = 45; laggerCarrySpeedValue = 25
        extraSpeedValue = 34; extraCarrySpeedValue = 29; autoTpDownValue = false; autoTpHeightValue = 10
        antiRagdollValue = false; State.infJumpEnabled = false; selectedAnimationPack = "OFF"
        AnimationPackIndex = 1; animValueLabel.Text = "OFF"; applyAnimationPack("OFF"); saveAllSettings()
        print("Config Reset to Defaults!")
    end)
end)

-- ==========================================
-- Open / Close Smooth Animation Logic
-- ==========================================
local isOpen = false
local openTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local closeTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

local fullSize = UDim2.new(0, 280, 0, 420)
local zeroSize = UDim2.new(0, 0, 0, 0)

toggleButton.MouseButton1Click:Connect(function()
    if not isOpen then isOpen = true; mainFrame.Visible = true; mainFrame.Size = zeroSize
        local openTween = TweenService:Create(mainFrame, openTweenInfo, {Size = fullSize}); openTween:Play()
    else isOpen = false
        local closeTween = TweenService:Create(mainFrame, closeTweenInfo, {Size = zeroSize}); closeTween:Play()
        closeTween.Completed:Connect(function() if not isOpen then mainFrame.Visible = false end end)
    end
end)

print("✅ Sound Hub V3.5 + VISUALS Loaded Successfully on Delta Executor!")
