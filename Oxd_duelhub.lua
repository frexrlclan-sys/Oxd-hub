--! ROBLOX_OXD_Hub_Brainrot_Duel
-- Developed by OXD

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

-- Configuration
local Config = {
    AutoBattle = {
        Enabled = false,
        Delay = 0.1, -- Delay between attacks
        AttackRadius = 15, -- How close enemy needs to be to auto-attack
        TargetPriority = "Nearest", -- "Nearest" or "LowestHealth" (if applicable)
        PreferPlayers = true, -- Prioritize players over NPCs
    },
    AntiAfk = {
        Enabled = false,
        Interval = 60, -- Seconds between anti-afk actions
    },
    Notifications = {
        Enabled = true,
        Duration = 3, -- Seconds notification stays on screen
        FadeTime = 0.5,
    },
    GUI = {
        Enabled = true,
        Position = UDim2.new(0.01, 0, 0.08, 0),
        Size = UDim2.new(0.25, 0, 0.45, 0),
        HeaderColor = Color3.fromRGB(40, 40, 40),
        BackgroundColor = Color3.fromRGB(30, 30, 30),
        TextColor = Color3.fromRGB(200, 200, 200),
        AccentColor = Color3.fromRGB(0, 150, 255),
        ToggleOnColor = Color3.fromRGB(50, 200, 50),
        ToggleOffColor = Color3.fromRGB(200, 50, 50),
        CornerRadius = 8,
    },
    Keybinds = {
        ToggleGUI = Enum.KeyCode.RightControl,
    },
}

-- Internals
local _G_OXD = {}
_G_OXD.Initialized = false
_G_OXD.Notifications = {}
_G_OXD.HeartbeatConnection = nil
_G_OXD.RenderSteppedConnection = nil
_G_OXD.AfkTimer = 0
_G_OXD.LastAttackTime = 0

-- GUI Elements
local ScreenGui
local MainFrame
local Header
local CloseButton
local DragOffset

-- Utility Functions
local function pcallProtected(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("OXD Hub: Error caught in pcallProtected:", result)
    end
    return success, result
end

local function notify(message, duration, color)
    if not Config.Notifications.Enabled then return end

    local notifFrame = Instance.new("Frame")
    notifFrame.AnchorPoint = Vector2.new(0.5, 0)
    notifFrame.BackgroundTransparency = 1
    notifFrame.Size = UDim2.new(0, 300, 0, 40)
    notifFrame.Position = UDim2.new(0.5, 0, 0.95, 0) -- Start at bottom
    notifFrame.ZIndex = 100

    local notifText = Instance.new("TextLabel")
    notifText.BackgroundTransparency = 0.9
    notifText.BackgroundColor3 = color or Config.GUI.AccentColor
    notifText.Size = UDim2.new(1, 0, 1, 0)
    notifText.Text = message
    notifText.TextColor3 = Config.GUI.TextColor
    notifText.TextScaled = true
    notifText.Font = Enum.Font.SourceSansBold
    notifText.TextXAlignment = Enum.TextXAlignment.Center
    notifText.TextYAlignment = Enum.TextYAlignment.Center
    notifText.Parent = notifFrame

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, Config.GUI.CornerRadius)
    UICorner.Parent = notifText

    notifFrame.Parent = ScreenGui.NotificationsFrame
    table.insert(_G_OXD.Notifications, notifFrame)

    for i, frame in ipairs(_G_OXD.Notifications) do
        local targetY = 0.95 - (i - 1) * 0.06
        TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, targetY, 0)}):Play()
    end

    delay(duration or Config.Notifications.Duration, function()
        local index = table.find(_G_OXD.Notifications, notifFrame)
        if index then
            TweenService:Create(notifText, TweenInfo.new(Config.Notifications.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
            TweenService:Create(notifText, TweenInfo.new(Config.Notifications.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
            delay(Config.Notifications.FadeTime, function()
                notifFrame:Destroy()
                table.remove(_G_OXD.Notifications, index)
                -- Re-align remaining notifications
                for i_2, frame_2 in ipairs(_G_OXD.Notifications) do
                    local targetY = 0.95 - (i_2 - 1) * 0.06
                    TweenService:Create(frame_2, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, targetY, 0)}):Play()
                end
            end)
        end
    end)
end

-- GUI Functions
local function createButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 30)
    button.BackgroundColor3 = Config.GUI.AccentColor
    button.TextColor3 = Config.GUI.TextColor
    button.Text = text
    button.Font = Enum.Font.SourceSansSemibold
    button.TextScaled = true
    button.TextWrapped = true
    button.Parent = parent
    button.AutomaticSize = Enum.AutomaticSize.Y
    button.TextSize = 16

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, Config.GUI.CornerRadius / 2)
    UICorner.Parent = button

    button.MouseButton1Click:Connect(function()
        pcallProtected(callback)
    end)
    return button
end

local function createToggle(parent, text, initialValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0.7, 0, 1, 0)
    textLabel.Size = UDim2.new(1, -40, 1, 0)
    textLabel.Position = UDim2.new(0, 0, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Config.GUI.TextColor
    textLabel.Text = text
    textLabel.Font = Enum.Font.SourceSansSemibold
    textLabel.TextScaled = true
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 40, 1, 0)
    toggleButton.Position = UDim2.new(1, -40, 0, 0)
    toggleButton.BackgroundColor3 = initialValue and Config.GUI.ToggleOnColor or Config.GUI.ToggleOffColor
    toggleButton.TextColor3 = Config.GUI.TextColor
    toggleButton.Text = initialValue and "ON" or "OFF"
    toggleButton.Font = Enum.Font.SourceSansSemibold
    toggleButton.TextScaled = true
    toggleButton.Parent = frame

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, Config.GUI.CornerRadius / 2)
    UICorner.Parent = toggleButton

    local value = initialValue
    toggleButton.MouseButton1Click:Connect(function()
        value = not value
        toggleButton.BackgroundColor3 = value and Config.GUI.ToggleOnColor or Config.GUI.ToggleOffColor
        toggleButton.Text = value and "ON" or "OFF"
        pcallProtected(callback, value)
    end)

    return value, frame, toggleButton
end

local function findAttackFunction()
    -- Common attack remote events/functions
    local potentialAttackRemotes = {
        "AttackEvent", "DamageEvent", "FireWeapon", "MeleeAttack", "Click", "LeftClick", "Attack", "CombatEvent",
        "PerformAttack", "RequestAttack", "Swing", "ActivateAbility", "ServerDamageEvent",
    }

    -- Search for RemoteEvents in ReplicatedStorage, Workspace, etc.
    local function searchForRemote(instance, name)
        for _, child in ipairs(instance:GetChildren()) do
            if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) then
                if string.find(child.Name:lower(), name:lower()) then
                    return child
                end
            end
            if string.find(child.Name:lower(), "combat") or string.find(child.Name:lower(), "attack") then
                -- Even if name doesn't match perfectly, return if it's in a relevant folder
                local found = searchForRemote(child, name)
                if found then return found end
            end
        end
        return nil
    end

    for _, eventName in ipairs(potentialAttackRemotes) do
        local remote = searchForRemote(ReplicatedStorage, eventName)
        if remote then return remote end
        remote = searchForRemote(workspace, eventName)
        if remote then return remote end
        -- Add more search locations if needed
    end

    -- If no direct remote is found, look for PlayerModule's control scripts
    -- (Less reliable for 'brainrot duel' type games, but good fallback for generic attacking)
    if LocalPlayer.PlayerScripts then
        for _, script in ipairs(LocalPlayer.PlayerScripts:GetDescendants()) do
            if script:IsA("ModuleScript") or script:IsA("LocalScript") then
                if string.find(script.Name:lower(), "playercombat") or string.find(script.Name:lower(), "playerskills") or string.find(script.Name:lower(), "controls") then
                    -- This is where it gets complex. We can't actually *hook* a module easily from an external script
                    -- without loading it first. For a generic script, we'd look for calls to RemoteEvents.
                    -- For now, we'll try to find a direct event.
                end
            end
        end
    end

    return nil -- No suitable attack function/remote found
end

_G_OXD.AttackRemote = nil

local function setupAttackRemote()
    if _G_OXD.AttackRemote then return end
    
    local success, remote = pcallProtected(findAttackFunction)
    if success and remote then
        _G_OXD.AttackRemote = remote
        notify("Found attack event: " .. remote.Name, 2)
    else
        notify("Could not find a reliable attack event. Auto-battle may not work.", 3, Color3.fromRGB(255, 100, 100))
    end
end

-- Core Logic
local function getCharacters()
    local characters = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.Humanoid.Health > 0 then
            table.insert(characters, player.Character)
        end
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("Humanoid") and child:FindFirstChild("HumanoidRootPart") and child.Humanoid.Health > 0 then
            local isPlayerCharacter = Players:GetPlayerFromCharacter(child) ~= nil
            if not isPlayerCharacter then
                table.insert(characters, child)
            end
        end
    end
    return characters
end

local function findTarget()
    local localCharacter = LocalPlayer.Character
    if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then return nil end

    local localRootPart = localCharacter.HumanoidRootPart
    local validTargets = {}

    for _, char in ipairs(getCharacters()) do
        if char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            local distance = (localRootPart.Position - char.HumanoidRootPart.Position).Magnitude
            if distance <= Config.AutoBattle.AttackRadius then
                table.insert(validTargets, {Character = char, Distance = distance, IsPlayer = Players:GetPlayerFromCharacter(char) ~= nil})
            end
        end
    end

    if #validTargets == 0 then return nil end

    -- Sort targets based on priority
    table.sort(validTargets, function(a, b)
        if Config.AutoBattle.PreferPlayers then
            if a.IsPlayer and not b.IsPlayer then return true end
            if not a.IsPlayer and b.IsPlayer then return false end
        end
        
        -- Default to nearest
        return a.Distance < b.Distance
    end)

    return validTargets[1].Character
end

local function autoBattleTick(deltaTime)
    _G_OXD.AfkTimer = _G_OXD.AfkTimer + deltaTime

    if Config.AutoBattle.Enabled then
        local currentTime = os.time()
        if currentTime - _G_OXD.LastAttackTime >= Config.AutoBattle.Delay then
            local target = findTarget()
            if target and _G_OXD.AttackRemote then
                pcallProtected(function()
                    _G_OXD.AttackRemote:FireServer(target) -- Generic firing
                end)
                _G_OXD.LastAttackTime = currentTime
            end
        end
    end

    if Config.AntiAfk.Enabled and _G_OXD.AfkTimer >= Config.AntiAfk.Interval then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            -- Jump action for anti-afk
            pcallProtected(function()
                LocalPlayer.Character.Humanoid.Jump = true
            end)
            notify("Anti-AFK: Jumped!", 1)
        end
        _G_OXD.AfkTimer = 0
    end
end

-- GUI Construction
local function createGUI()
    if Config.GUI.Enabled then
        if ScreenGui then ScreenGui:Destroy() end

        ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "OxdHub_GUI"
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

        -- Notifications Frame (always active even if main GUI is hidden)
        ScreenGui.NotificationsFrame = Instance.new("Frame")
        ScreenGui.NotificationsFrame.Size = UDim2.new(1, 0, 1, 0)
        ScreenGui.NotificationsFrame.BackgroundTransparency = 1
        ScreenGui.NotificationsFrame.Name = "NotificationsFrame"
        ScreenGui.NotificationsFrame.Parent = ScreenGui

        MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = Config.GUI.Size
        MainFrame.Position = Config.GUI.Position
        MainFrame.BackgroundColor3 = Config.GUI.BackgroundColor
        MainFrame.Active = true
        MainFrame.Draggable = true
        MainFrame.Parent = ScreenGui

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, Config.GUI.CornerRadius)
        UICorner.Parent = MainFrame

        Header = Instance.new("Frame")
        Header.Name = "Header"
        Header.Size = UDim2.new(1, 0, 0, 30)
        Header.BackgroundColor3 = Config.GUI.HeaderColor
        Header.Parent = MainFrame

        local HeaderText = Instance.new("TextLabel")
        HeaderText.Name = "HeaderText"
        HeaderText.Size = UDim2.new(1, -30, 1, 0)
        HeaderText.Position = UDim2.new(0, 5, 0, 0)
        HeaderText.BackgroundTransparency = 1
        HeaderText.TextColor3 = Config.GUI.TextColor
        HeaderText.Text = "OXD Brainrot Duel Hub"
        HeaderText.Font = Enum.Font.SourceSansBold
        HeaderText.TextScaled = true
        HeaderText.TextXAlignment = Enum.TextXAlignment.Left
        HeaderText.Parent = Header

        CloseButton = Instance.new("TextButton")
        CloseButton.Name = "CloseButton"
        CloseButton.Size = UDim2.new(0, 30, 1, 0)
        CloseButton.Position = UDim2.new(1, -30, 0, 0)
        CloseButton.BackgroundColor3 = Config.GUI.ToggleOffColor
        CloseButton.TextColor3 = Config.GUI.TextColor
        CloseButton.Text = "X"
        CloseButton.Font = Enum.Font.SourceSansBold
        CloseButton.TextScaled = true
        CloseButton.Parent = Header

        CloseButton.MouseButton1Click:Connect(function()
            MainFrame.Visible = false
        end)

        Header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                DragOffset = MainFrame.Position - UDim2.new(0, input.Position.X, 0, input.Position.Y)
            end
        })

        Header.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                if DragOffset then
                    MainFrame.Position = UDim2.new(0, input.Position.X, 0, input.Position.Y) + DragOffset
                end
            end
        })

        Header.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                DragOffset = nil
            end
        })

        local ScrollingFrame = Instance.new("ScrollingFrame")
        ScrollingFrame.Size = UDim2.new(1, 0, 1, -30)
        ScrollingFrame.Position = UDim2.new(0, 0, 0, 30)
        ScrollingFrame.BackgroundTransparency = 1
        ScrollingFrame.Parent = MainFrame
        ScrollingFrame.ScrollBarImageColor3 = Config.GUI.AccentColor
        ScrollingFrame.ScrollBarThickness = 6
        ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be updated by UIListLayout
        ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y

        local UIListLayout = Instance.new("UIListLayout")
        UIListLayout.Padding = UDim.new(0, 5)
        UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
        UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIListLayout.FillDirection = Enum.FillDirection.Vertical
        UIListLayout.Parent = ScrollingFrame

        local UIPadding = Instance.new("UIPadding")
        UIPadding.PaddingLeft = UDim.new(0, 5)
        UIPadding.PaddingRight = UDim.new(0, 5)
        UIPadding.PaddingTop = UDim.new(0, 5)
        UIPadding.PaddingBottom = UDim.new(0, 5)
        UIPadding.Parent = ScrollingFrame

        createToggle(ScrollingFrame, "Auto Battle", Config.AutoBattle.Enabled, function(value)
            Config.AutoBattle.Enabled = value
            notify("Auto Battle: " .. (value and "Enabled" or "Disabled"), 1)
            if value then setupAttackRemote() end
        end)

        createToggle(ScrollingFrame, "Anti-AFK", Config.AntiAfk.Enabled, function(value)
            Config.AntiAfk.Enabled = value
            _G_OXD.AfkTimer = 0
            notify("Anti-AFK: " .. (value and "Enabled" or "Disabled"), 1)
        end)

        createToggle(ScrollingFrame, "Notifications", Config.Notifications.Enabled, function(value)
            Config.Notifications.Enabled = value
            notify("Notifications: " .. (value and "Enabled" or "Disabled"), 1)
        end)

        createButton(ScrollingFrame, "Re-Scan Attack Event", function()
            _G_OXD.AttackRemote = nil
            setupAttackRemote()
        end)
    end
end

-- Initialization
local function init()
    if _G_OXD.Initialized then return end
    _G_OXD.Initialized = true

    notify("OXD Hub Initializing...", 2)

    createGUI()

    -- Connect main game loop
    _G_OXD.HeartbeatConnection = RunService.Heartbeat:Connect(autoBattleTick)

    -- Toggle GUI with keybind
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if not gameProcessedEvent and input.KeyCode == Config.Keybinds.ToggleGUI then
            if MainFrame then
                MainFrame.Visible = not MainFrame.Visible
                notify("GUI " .. (MainFrame.Visible and "Shown" or "Hidden"), 1)
            end
        end
    end)
    
    setupAttackRemote() -- Attempt to find attack remote on startup

    notify("OXD Hub Loaded!", 2, Color3.fromRGB(0, 200, 0))
    warn("OXD Hub: Brainrot Duel script loaded.")
end

-- Ensure init runs only once and after player/character ready
if LocalPlayer.Character then
    pcallProtected(init)
else
    LocalPlayer.CharacterAdded:Wait()
    pcallProtected(init)
end

-- Self-destruct function for cleanup (optional)
_G_OXD.Destroy = function()
    if _G_OXD.HeartbeatConnection then _G_OXD.HeartbeatConnection:Disconnect() end
    if _G_OXD.RenderSteppedConnection then _G_OXD.RenderSteppedConnection:Disconnect() end
    if ScreenGui then ScreenGui:Destroy() end
    _G_OXD.Initialized = false
    notify("OXD Hub Destroyed.", 2, Color3.fromRGB(200, 0, 0))
    warn("OXD Hub: Cleaning up...")
    
    -- Clear global state
    for k, v in pairs(_G_OXD) do _G_OXD[k] = nil end
    _G_OXD = nil
end
-- You could expose _G_OXD.Destroy() if you wanted a gui button 
