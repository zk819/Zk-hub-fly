local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = {
    WallSystem = true,
    AntiRagdoll = true,
    AntiItem = true,
    GodMode = false,
    InfiniteJump = true,
    Float = false,
    FloatHeight = 3,
    SpeedHack = true,
    SpeedValue = 110,
    ESPMaster = false,
    ESPBoxes = true,
    ESPNames = true,
    ESPDistance = true,
    ESPTeamColor = true,
    FlyEnabled = false,
    SidebarRetract = false,
    Notifications = true,
    SoundEffects = false,
}

local FPS = 60
RunService.RenderStepped:Connect(function()
    FPS = math.floor(1 / RunService.RenderStepped:Wait())
end)

local originalTransparency = {}
local function isPlayerBase(obj)
    if not (obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation")) then return false end
    local n = obj.Name:lower()
    local p = obj.Parent and obj.Parent.Name:lower() or ""
    return n:find("base") or n:find("claim") or p:find("base") or p:find("claim")
end

local function applyWallSystem(enable)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isPlayerBase(obj) then
            if enable then
                originalTransparency[obj] = obj.LocalTransparencyModifier
                obj.LocalTransparencyModifier = 0.8
            else
                obj.LocalTransparencyModifier = originalTransparency[obj] or 0
            end
        end
    end
end

Workspace.DescendantAdded:Connect(function(obj)
    if Config.WallSystem and isPlayerBase(obj) then
        originalTransparency[obj] = obj.LocalTransparencyModifier
        obj.LocalTransparencyModifier = 0.8
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Config.WallSystem then applyWallSystem(true) end
end)
local espCache = {}
local function createESP(plr)
    local esp = {
        box = Drawing.new("Square"),
        name = Drawing.new("Text"),
        dist = Drawing.new("Text"),
    }
    esp.box.Visible = false
    esp.box.Color = plr.TeamColor.Color
    esp.box.Thickness = 2
    esp.box.Filled = false
    esp.name.Visible = false
    esp.name.Color = Color3.new(1,1,1)
    esp.name.Size = 16
    esp.name.Center = true
    esp.name.Outline = true
    esp.dist.Visible = false
    esp.dist.Color = Color3.new(1,1,0)
    esp.dist.Size = 14
    esp.dist.Center = true
    esp.dist.Outline = true
    espCache[plr] = esp
end

local function updateESP()
    if not Config.ESPMaster then
        for _, esp in pairs(espCache) do
            esp.box.Visible = false
            esp.name.Visible = false
            esp.dist.Visible = false
        end
        return
    end
    local camera = Workspace.CurrentCamera
    local myPos = camera.CFrame.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local root = plr.Character.HumanoidRootPart
            local pos, onScreen = camera:WorldToViewportPoint(root.Position)
            local dist = (root.Position - myPos).Magnitude
            local esp = espCache[plr]
            if not esp then createESP(plr) esp = espCache[plr] end
            if onScreen then
                local size = Vector2.new(2000 / dist, 3000 / dist)
                local topLeft = Vector2.new(pos.X - size.X/2, pos.Y - size.Y/2)
                local bottomRight = Vector2.new(pos.X + size.X/2, pos.Y + size.Y/2)
                esp.box.Visible = Config.ESPBoxes
                esp.box.From = topLeft
                esp.box.To = bottomRight
                esp.box.Color = Config.ESPTeamColor and plr.TeamColor.Color or Color3.new(1,1,1)
                esp.name.Visible = Config.ESPNames
                esp.name.Position = Vector2.new(pos.X, topLeft.Y - 18)
                esp.name.Text = plr.Name
                esp.dist.Visible = Config.ESPDistance
                esp.dist.Position = Vector2.new(pos.X, bottomRight.Y + 4)
                esp.dist.Text = string.format("%.1f m", dist)
            else
                esp.box.Visible = false
                esp.name.Visible = false
                esp.dist.Visible = false
            end
        end
    end
end
RunService.RenderStepped:Connect(updateESP)

local Frozen = false
local DisabledRemotes = {}
local RemoteWatcher
local BlockedStates = {
    [Enum.HumanoidStateType.Ragdoll] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics] = true,
    [Enum.HumanoidStateType.Dead] = true
}
local RemoteKeywords = { "useitem", "combatservice", "ragdoll" }

local function ForceNormal(character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    hum.Health = hum.MaxHealth
    hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
    if not Frozen then
        Frozen = true
        hrp.Anchored = true
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame += Vector3.new(0, 1.5, 0)
    end
end

local function Release(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp and Frozen then
        hrp.Anchored = false
        Frozen = false
    end
end

local function RestoreMotors(character)
    for _, v in ipairs(character:GetDescendants()) do
        if v:IsA("Motor6D") then v.Enabled = true
        elseif v:IsA("Constraint") then v.Enabled = false end
    end
end

local function InitAntiRagdoll(character)
    local hum = character:WaitForChild("Humanoid", 10)
    if not hum then return end
    for state in pairs(BlockedStates) do
        hum:SetStateEnabled(state, false)
    end
    hum.StateChanged:Connect(function(_, new)
        if Config.AntiRagdoll and BlockedStates[new] then
            ForceNormal(character)
            RestoreMotors(character)
        end
    end)
    RunService.Stepped:Connect(function()
        if not Config.AntiRagdoll then Release(character) return end
        if BlockedStates[hum:GetState()] then ForceNormal(character) else Release(character) end
        hum.Health = hum.MaxHealth
    end)
end

local function KillRemote(remote)
    if not getconnections or not remote:IsA("RemoteEvent") then return end
    if DisabledRemotes[remote] then return end
    local name = remote.Name:lower()
    for _, key in ipairs(RemoteKeywords) do
        if name:find(key) then
            DisabledRemotes[remote] = {}
            for _, c in ipairs(getconnections(remote.OnClientEvent)) do
                if c.Disable then c:Disable() table.insert(DisabledRemotes[remote], c) end
            end
            break
        end
    end
end

local function InitAntiItem()
    pcall(function()
        local PlayerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
        local Controls = PlayerModule:GetControls()
        Controls:Enable()
    end)
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do KillRemote(obj) end
    RemoteWatcher = ReplicatedStorage.DescendantAdded:Connect(function(obj)
        if Config.AntiItem then KillRemote(obj) end
    end)
end

if player.Character then InitAntiRagdoll(player.Character) end
player.CharacterAdded:Connect(function(char) task.wait(0.4) InitAntiRagdoll(char) end)
if Config.AntiItem then task.delay(0.25, InitAntiItem) end

local function applyGodMode(character, enable)
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if enable then
        humanoid.MaxHealth = math.huge
        humanoid.Health = humanoid.MaxHealth
        humanoid.BreakJointsOnDeath = false
        local conn = humanoid.HealthChanged:Connect(function()
            if humanoid.Health <= 0 then humanoid.Health = humanoid.MaxHealth end
        end)
        _G.GodModeConns = _G.GodModeConns or {}
        _G.GodModeConns[character] = conn
    else
        if _G.GodModeConns and _G.GodModeConns[character] then
            _G.GodModeConns[character]:Disconnect()
            _G.GodModeConns[character] = nil
        end
    end
end

local function setupGodModeForCharacter(character)
    task.wait(0.5)
    applyGodMode(character, Config.GodMode)
end
if player.Character then setupGodModeForCharacter(player.Character) end
player.CharacterAdded:Connect(setupGodModeForCharacter)
RunService.Heartbeat:Connect(function()
    if not Config.InfiniteJump then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Velocity.Y < -80 then
        hrp.Velocity = Vector3.new(hrp.Velocity.X, -80, hrp.Velocity.Z)
    end
end)

UserInputService.JumpRequest:Connect(function()
    if not Config.InfiniteJump then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Velocity = Vector3.new(hrp.Velocity.X, 50, hrp.Velocity.Z)
    end
end)

local floatPlatform = nil
local function updateFloat()
    if not Config.Float then
        if floatPlatform then floatPlatform:Destroy() floatPlatform = nil end
        return
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not floatPlatform then
        floatPlatform = Instance.new("Part")
        floatPlatform.Size = Vector3.new(6, 1, 6)
        floatPlatform.Anchored = true
        floatPlatform.CanCollide = true
        floatPlatform.Transparency = 1
        floatPlatform.Parent = Workspace
    end
    floatPlatform.Position = hrp.Position - Vector3.new(0, Config.FloatHeight, 0)
end
RunService.Heartbeat:Connect(updateFloat)

local speedConnection = nil
local function updateSpeedHack()
    if speedConnection then speedConnection:Disconnect() end
    if not Config.SpeedHack then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    speedConnection = RunService.Heartbeat:Connect(function()
        if not Config.SpeedHack or not humanoid or not hrp then return end
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            hrp.AssemblyLinearVelocity = Vector3.new(
                moveDir.X * Config.SpeedValue,
                hrp.AssemblyLinearVelocity.Y,
                moveDir.Z * Config.SpeedValue
            )
        end
    end)
end
player.CharacterAdded:Connect(function() task.wait(0.5) updateSpeedHack() end)
updateSpeedHack()

local flyUI = nil
local flyEnabled = false
local flySpeed = 50
local flyMode = "asa"
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flyConnection = nil
local flyCharacter = nil
local flyHumanoid = nil
local flyRootPart = nil

local function desativarFly()
    flyEnabled = false
    if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
end

local function ativarFly()
    if not flyRootPart or not flyHumanoid then return end
    flyEnabled = true
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.Velocity = Vector3.new(0,0,0)
    flyBodyVelocity.MaxForce = Vector3.new(5000, 5000, 5000)
    flyBodyVelocity.Parent = flyRootPart
    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(5000, 5000, 5000)
    flyBodyGyro.P = 1000
    flyBodyGyro.D = 50
    flyBodyGyro.Parent = flyRootPart
    flyConnection = RunService.Heartbeat:Connect(function()
        if not flyEnabled or not flyRootPart or not flyHumanoid then return end
        local camera = workspace.CurrentCamera
        local camCF = camera.CFrame
        local moveDirection = flyHumanoid.MoveDirection
        if moveDirection.Magnitude > 0 then
            local forwardAmount = moveDirection:Dot(camCF.LookVector)
            local rightAmount = moveDirection:Dot(camCF.RightVector)
            local finalDir = (camCF.LookVector * forwardAmount) + (camCF.RightVector * rightAmount)
            if finalDir.Magnitude > 0 then finalDir = finalDir.Unit end
            flyBodyVelocity.Velocity = finalDir * flySpeed
        else
            flyBodyVelocity.Velocity = Vector3.new(0,0,0)
        end
        flyBodyGyro.CFrame = camCF
        if flyMode == "turbo" then
            flyBodyVelocity.Velocity = flyBodyVelocity.Velocity * 1.5
        elseif flyMode == "drift" then
            flyBodyGyro.P = 500
        else
            flyBodyGyro.P = 1000
        end
    end)
end

local function setupFlyCharacter(newCharacter)
    flyCharacter = newCharacter
    flyHumanoid = newCharacter:WaitForChild("Humanoid")
    flyRootPart = newCharacter:WaitForChild("HumanoidRootPart")
    desativarFly()
    flyHumanoid.Died:Connect(desativarFly)
end
if player.Character then setupFlyCharacter(player.Character) end
player.CharacterAdded:Connect(setupFlyCharacter)
local function createFlyUI()
    if flyUI then flyUI:Destroy() end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FlyHub"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 180)
    frame.Position = UDim2.new(0.5, -125, 0.8, -90)
    frame.BackgroundColor3 = Color3.fromRGB(13, 15, 20)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 229, 255)
    stroke.Thickness = 2
    stroke.Parent = frame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = frame
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 35)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "⚡ FLY HUB V3"
    title.TextColor3 = Color3.fromRGB(230, 230, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextStrokeColor3 = Color3.fromRGB(160, 32, 240)
    title.TextStrokeTransparency = 0.5
    title.Parent = frame
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0.9, 0, 0, 2)
    line.Position = UDim2.new(0.05, 0, 0, 40)
    line.BackgroundColor3 = Color3.fromRGB(0, 229, 255)
    line.BorderSizePixel = 0
    line.Parent = frame
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
    toggleBtn.Position = UDim2.new(0.1, 0, 0, 50)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(26, 31, 43)
    toggleBtn.Text = "FLY: OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextScaled = true
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = frame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 20)
    btnCorner.Parent = toggleBtn
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(160, 32, 240)
    btnStroke.Thickness = 1.5
    btnStroke.Parent = toggleBtn
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Size = UDim2.new(0.8, 0, 0, 20)
    speedLabel.Position = UDim2.new(0.1, 0, 0, 100)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "Velocidade: 50"
    speedLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextScaled = true
    speedLabel.Parent = frame
    local speedValue = Instance.new("TextLabel")
    speedValue.Size = UDim2.new(0, 40, 0, 20)
    speedValue.Position = UDim2.new(0.75, 0, 0, 100)
    speedValue.BackgroundTransparency = 1
    speedValue.Text = "50"
    speedValue.TextColor3 = Color3.fromRGB(0, 229, 255)
    speedValue.Font = Enum.Font.GothamBold
    speedValue.TextScaled = true
    speedValue.Parent = frame
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(0.8, 0, 0, 15)
    sliderBg.Position = UDim2.new(0.1, 0, 0, 125)
    sliderBg.BackgroundColor3 = Color3.fromRGB(26, 31, 43)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = frame
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 8)
    sliderCorner.Parent = sliderBg
    local fillBar = Instance.new("Frame")
    fillBar.Size = UDim2.new(0.166, 0, 1, 0)
    fillBar.BackgroundColor3 = Color3.fromRGB(0, 229, 255)
    fillBar.BorderSizePixel = 0
    fillBar.Parent = sliderBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 8)
    fillCorner.Parent = fillBar
    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(1, 0, 1, 0)
    sliderButton.BackgroundTransparency = 1
    sliderButton.Text = ""
    sliderButton.AutoButtonColor = false
    sliderButton.Parent = sliderBg
    local function updateSliderFromPosition(position)
        if not position then return end
        local absPos = sliderBg.AbsolutePosition.X
        local size = sliderBg.AbsoluteSize.X
        local rel = math.clamp((position.X - absPos) / size, 0, 1)
        flySpeed = math.floor(rel * 300)
        speedLabel.Text = "Velocidade: " .. flySpeed
        speedValue.Text = tostring(flySpeed)
        fillBar.Size = UDim2.new(rel, 0, 1, 0)
    end
    sliderButton.MouseButton1Down:Connect(function(input)
        updateSliderFromPosition(input)
        local moveConn
        moveConn = UserInputService.InputChanged:Connect(function(inputChanged)
            if inputChanged.UserInputType == Enum.UserInputType.MouseMovement then
                updateSliderFromPosition(inputChanged)
            end
        end)
        local endedConn
        endedConn = UserInputService.InputEnded:Connect(function(inputEnded)
            if inputEnded.UserInputType == Enum.UserInputType.MouseButton1 then
                moveConn:Disconnect()
                endedConn:Disconnect()
            end
        end)
    end)
    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            updateSliderFromPosition(input)
            local moveConn
            moveConn = UserInputService.InputChanged:Connect(function(inputChanged)
                if inputChanged.UserInputType == Enum.UserInputType.Touch then
                    updateSliderFromPosition(inputChanged)
                end
            end)
            local endedConn
            endedConn = UserInputService.InputEnded:Connect(function(inputEnded)
                if inputEnded.UserInputType == Enum.UserInputType.Touch then
                    moveConn:Disconnect()
                    endedConn:Disconnect()
                end
            end)
        end
    end)
    local modeFrame = Instance.new("Frame")
    modeFrame.Size = UDim2.new(0.9, 0, 0, 40)
    modeFrame.Position = UDim2.new(0.05, 0, 0, 150)
    modeFrame.BackgroundTransparency = 1
    modeFrame.Parent = frame
    local function createModeButton(icon, mode, xPos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 50, 0, 35)
        btn.Position = UDim2.new(xPos, 0, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
        btn.Text = icon
        btn.TextColor3 = Color3.fromRGB(0, 229, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextScaled = true
        btn.BorderSizePixel = 0
        btn.Parent = modeFrame
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 10)
        btnCorner.Parent = btn
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(160, 32, 240)
        stroke.Thickness = 1.5
        stroke.Parent = btn
        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(1, 0, 0, 3)
        indicator.Position = UDim2.new(0, 0, 1, -3)
        indicator.BackgroundColor3 = Color3.fromRGB(0, 229, 255)
        indicator.BackgroundTransparency = 0.5
        indicator.BorderSizePixel = 0
        indicator.Visible = (mode == flyMode)
        indicator.Parent = btn
        return btn, indicator
    end
    local asaBtn, asaInd = createModeButton("🪽", "asa", 0)
    local turboBtn, turboInd = createModeButton("🚀", "turbo", 0.34)
    local driftBtn, driftInd = createModeButton("☁", "drift", 0.68)
    local function setMode(mode)
        flyMode = mode
        asaInd.Visible = (mode == "asa")
        turboInd.Visible = (mode == "turbo")
        driftInd.Visible = (mode == "drift")
    end
    asaBtn.MouseButton1Click:Connect(function() setMode("asa") end)
    turboBtn.MouseButton1Click:Connect(function() setMode("turbo") end)
    driftBtn.MouseButton1Click:Connect(function() setMode("drift") end)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextScaled = true
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = frame
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        flyUI = nil
    end)
    toggleBtn.MouseButton1Click:Connect(function()
        if not flyRootPart then return end
        if flyEnabled then
            desativarFly()
            toggleBtn.Text = "FLY: OFF"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(26, 31, 43)
            local stroke = toggleBtn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = Color3.fromRGB(160, 32, 240) end
        else
            ativarFly()
            toggleBtn.Text = "FLY: ON"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 100)
            local stroke = toggleBtn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = Color3.fromRGB(255, 255, 255) end
        end
    end)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(0, 200, 0, 30)
    hint.Position = UDim2.new(0.5, -100, 0.95, -40)
    hint.BackgroundTransparency = 1
    hint.Text = "👆 Use o joystick para voar"
    hint.TextColor3 = Color3.fromRGB(200, 200, 255)
    hint.TextScaled = true
    hint.Font = Enum.Font.Gotham
    hint.Parent = screenGui
    flyUI = screenGui
    return screenGui
end

local function toggleFlyFromHub(enable)
    if enable then
        if not flyUI then createFlyUI() end
    else
        if flyUI then flyUI:Destroy() flyUI = nil end
        desativarFly()
    end
end

local function Notify(message, duration)
    if not Config.Notifications then return end
    duration = duration or 3
    local notif = Instance.new("ScreenGui")
    notif.Name = "Notification"
    notif.Parent = playerGui
    notif.ResetOnSpawn = false
    notif.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    notif.DisplayOrder = 2000
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 50)
    frame.Position = UDim2.new(0.5, -150, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = notif
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -20, 1, 0)
    text.Position = UDim2.new(0, 10, 0, 0)
    text.BackgroundTransparency = 1
    text.Text = message
    text.TextColor3 = Color3.new(1,1,1)
    text.TextSize = 16
    text.Font = Enum.Font.GothamBold
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = frame
    frame:TweenPosition(UDim2.new(0.5, -150, 0, 10), "Out", "Quad", 0.3, true)
    task.wait(duration)
    frame:TweenPosition(UDim2.new(0.5, -150, 0, -60), "Out", "Quad", 0.3, true)
    task.wait(0.3)
    notif:Destroy()
end

local function PlaySound()
    if not Config.SoundEffects then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxasset://sounds/notification.mp3"
    sound.Volume = 0.5
    sound.Parent = Workspace
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 2)
end
local UI = Instance.new("ScreenGui")
UI.Name = "ZkHubUltra"
UI.Parent = playerGui
UI.ResetOnSpawn = false
UI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
UI.DisplayOrder = 1000

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 550, 0, 650)
mainFrame.Position = UDim2.new(0.5, -275, 0.5, -325)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = UI
mainFrame.Visible = false

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 15)
mainCorner.Parent = mainFrame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 70)
header.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 15)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.6, 0, 0.6, 0)
title.Position = UDim2.new(0, 20, 0, 10)
title.BackgroundTransparency = 1
title.Text = "ZK HUB ULTRA"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 28
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local status = Instance.new("TextLabel")
status.Size = UDim2.new(0.6, 0, 0.3, 0)
status.Position = UDim2.new(0, 20, 0, 45)
status.BackgroundTransparency = 1
status.Text = "⚡ ONLINE"
status.TextColor3 = Color3.fromRGB(0, 255, 100)
status.TextSize = 14
status.Font = Enum.Font.GothamBold
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = header

local sysInfo = Instance.new("TextLabel")
sysInfo.Size = UDim2.new(0.4, -20, 1, 0)
sysInfo.Position = UDim2.new(0.6, 0, 0, 0)
sysInfo.BackgroundTransparency = 1
sysInfo.Text = "System Core v3.7 | FPS: 120 | 22ms"
sysInfo.TextColor3 = Color3.fromRGB(180, 180, 180)
sysInfo.TextSize = 12
sysInfo.Font = Enum.Font.Gotham
sysInfo.TextXAlignment = Enum.TextXAlignment.Right
sysInfo.Parent = header

spawn(function()
    while UI and UI.Parent do
        sysInfo.Text = string.format("System Core v3.7 | FPS: %d | 22ms", FPS)
        task.wait(0.5)
    end
end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 15)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextSize = 22
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

local tabButtons = {}
local tabContents = {}
local tabNames = {"PRINCIPAL", "MOVIMENTO", "VISUAL", "OUTROS"}
local tabColors = {Color3.fromRGB(70, 130, 200), Color3.fromRGB(200, 130, 70), Color3.fromRGB(130, 200, 70), Color3.fromRGB(200, 70, 130)}

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 40)
tabBar.Position = UDim2.new(0, 10, 0, 80)
tabBar.BackgroundTransparency = 1
tabBar.Parent = mainFrame

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 0, 35)
    btn.Position = UDim2.new(0, (i-1)*130, 0, 0)
    btn.BackgroundColor3 = i == 1 and tabColors[i] or Color3.fromRGB(50, 50, 50)
    btn.Text = name
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = tabBar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local tabContent = Instance.new("ScrollingFrame")
    tabContent.Size = UDim2.new(1, -20, 1, -180)
    tabContent.Position = UDim2.new(0, 10, 0, 130)
    tabContent.BackgroundTransparency = 1
    tabContent.ScrollBarThickness = 6
    tabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabContent.Visible = (i == 1)
    tabContent.Parent = mainFrame

    tabButtons[i] = btn
    tabContents[name] = tabContent

    btn.MouseButton1Click:Connect(function()
        for _, b in ipairs(tabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end
        btn.BackgroundColor3 = tabColors[i]
        for _, content in pairs(tabContents) do
            content.Visible = false
        end
        tabContent.Visible = true
    end)
end

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -20, 0, 25)
footer.Position = UDim2.new(0, 10, 1, -30)
footer.BackgroundTransparency = 1
footer.Text = "ZK HUB ULTRA PREMIUM EDITION | Powered by Dark Cyber System"
footer.TextColor3 = Color3.fromRGB(140, 140, 140)
footer.TextSize = 11
footer.Font = Enum.Font.Gotham
footer.Parent = mainFrame

local bar = Instance.new("Frame")
bar.Size = UDim2.new(0, 120, 0, 40)
bar.Position = UDim2.new(0, 20, 0, 20)
bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
bar.BackgroundTransparency = 0.1
bar.Active = true
bar.Draggable = true
bar.Parent = UI

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 20)
barCorner.Parent = bar

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(0, 229, 255)
barStroke.Thickness = 2
barStroke.Parent = bar

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0.7, -10, 1, 0)
openBtn.Position = UDim2.new(0, 5, 0, 0)
openBtn.BackgroundTransparency = 1
openBtn.Text = "ZK Hub +"
openBtn.TextColor3 = Color3.new(1,1,1)
openBtn.TextSize = 16
openBtn.Font = Enum.Font.GothamBold
openBtn.TextXAlignment = Enum.TextXAlignment.Left
openBtn.BorderSizePixel = 0
openBtn.Parent = bar

local barClose = Instance.new("TextButton")
barClose.Size = UDim2.new(0, 30, 0, 30)
barClose.Position = UDim2.new(1, -35, 0.5, -15)
barClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
barClose.Text = "✕"
barClose.TextColor3 = Color3.new(1,1,1)
barClose.TextSize = 16
barClose.Font = Enum.Font.GothamBold
barClose.BorderSizePixel = 0
barClose.Parent = bar

local barCloseCorner = Instance.new("UICorner")
barCloseCorner.CornerRadius = UDim.new(0, 8)
barCloseCorner.Parent = barClose

openBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

barClose.MouseButton1Click:Connect(function()
    UI:Destroy()
    toggleFlyFromHub(false)
    if speedConnection then speedConnection:Disconnect() end
    if floatPlatform then floatPlatform:Destroy() end
end)

local function createToggle(parent, y, text, var, default, callback)
    Config[var] = default
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.Position = UDim2.new(0, 5, 0, y)
    frame.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", frame)
    lbl.Text = text
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.TextSize = 16
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0, 60, 0, 30)
    btn.Position = UDim2.new(1, -70, 0.5, -15)
    btn.BackgroundColor3 = Config[var] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(100, 100, 100)
    btn.Text = Config[var] and "ON" or "OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        Config[var] = not Config[var]
        btn.BackgroundColor3 = Config[var] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(100, 100, 100)
        btn.Text = Config[var] and "ON" or "OFF"
        if callback then callback(Config[var]) end
        if Config.Notifications then Notify(text .. " " .. (Config[var] and "ativado" or "desativado")) end
        if Config.SoundEffects then PlaySound() end
    end)
    return 45
end

local function createSlider(parent, y, text, var, min, max, default, suffix, callback)
    Config[var] = default
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 60)
    frame.Position = UDim2.new(0, 5, 0, y)
    frame.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", frame)
    lbl.Text = text
    lbl.Size = UDim2.new(0.5, 0, 0, 20)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local valLbl = Instance.new("TextLabel", frame)
    valLbl.Size = UDim2.new(0.5, -10, 0, 20)
    valLbl.Position = UDim2.new(0.5, 0, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default) .. (suffix or "")
    valLbl.TextColor3 = Color3.fromRGB(100, 200, 255)
    valLbl.TextSize = 14
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    local bg = Instance.new("Frame", frame)
    bg.Size = UDim2.new(1, 0, 0, 8)
    bg.Position = UDim2.new(0, 0, 0, 25)
    bg.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    bg.BorderSizePixel = 0
    local bgCorner = Instance.new("UICorner", bg)
    bgCorner.CornerRadius = UDim.new(0, 4)
    local fill = Instance.new("Frame", bg)
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    fill.BorderSizePixel = 0
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(0, 4)
    local sliderBtn = Instance.new("TextButton", bg)
    sliderBtn.Size = UDim2.new(1, 0, 1, 0)
    sliderBtn.BackgroundTransparency = 1
    sliderBtn.Text = ""
    sliderBtn.AutoButtonColor = false
    local dragging = false
    local function updateFromInput(input)
        if not input or not input.Position then return end
        local pos = input.Position
        local absPos = bg.AbsolutePosition.X
        local absSize = bg.AbsoluteSize.X
        local rel = math.clamp((pos.X - absPos) / absSize, 0, 1)
        local value = math.floor(min + (max - min) * rel)
        if Config[var] ~= value then
            Config[var] = value
            valLbl.Text = tostring(value) .. (suffix or "")
            fill.Size = UDim2.new(rel, 0, 1, 0)
            if callback then callback(value) end
        end
    end
    sliderBtn.MouseButton1Down:Connect(function(input)
        dragging = true
        updateFromInput(input)
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromInput(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    sliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromInput(input)
        end
    end)
    sliderBtn.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.Touch then
            updateFromInput(input)
        end
    end)
    sliderBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    sliderBtn.MouseLeave:Connect(function() dragging = false end)
    return 65
end

local y = 0
local tab = tabContents["PRINCIPAL"]
local combatTitle = Instance.new("TextLabel", tab)
combatTitle.Size = UDim2.new(1, -10, 0, 30)
combatTitle.Position = UDim2.new(0, 5, 0, y)
combatTitle.BackgroundTransparency = 1
combatTitle.Text = "⚔️ COMBAT CORE"
combatTitle.TextColor3 = Color3.fromRGB(255, 200, 100)
combatTitle.TextSize = 20
combatTitle.Font = Enum.Font.GothamBold
combatTitle.TextXAlignment = Enum.TextXAlignment.Left
y = y + 35
y = y + createToggle(tab, y, "🧱 Wall System", "WallSystem", true, function(v) applyWallSystem(v) end)
y = y + createToggle(tab, y, "🚫 Anti-Ragdoll", "AntiRagdoll", true)
y = y + createToggle(tab, y, "🔇 Anti-Item", "AntiItem", true, function(v) if v then InitAntiItem() end end)
y = y + createToggle(tab, y, "🛡️ God Mode", "GodMode", false, function(v) if player.Character then applyGodMode(player.Character, v) end end)
y = y + 5
local advTitle = Instance.new("TextLabel", tab)
advTitle.Size = UDim2.new(1, -10, 0, 30)
advTitle.Position = UDim2.new(0, 5, 0, y)
advTitle.BackgroundTransparency = 1
advTitle.Text = "⚡ ADVANCED MOVEMENT"
advTitle.TextColor3 = Color3.fromRGB(100, 255, 150)
advTitle.TextSize = 20
advTitle.Font = Enum.Font.GothamBold
advTitle.TextXAlignment = Enum.TextXAlignment.Left
y = y + 35
y = y + createToggle(tab, y, "🦘 Infinite Jump", "InfiniteJump", true)
y = y + createToggle(tab, y, "☁️ Float", "Float", false)
y = y + 5

y = 0
tab = tabContents["MOVIMENTO"]
local speedTitle = Instance.new("TextLabel", tab)
speedTitle.Size = UDim2.new(1, -10, 0, 30)
speedTitle.Position = UDim2.new(0, 5, 0, y)
speedTitle.BackgroundTransparency = 1
speedTitle.Text = "🚀 SPEED ENGINE"
speedTitle.TextColor3 = Color3.fromRGB(255, 150, 100)
speedTitle.TextSize = 20
speedTitle.Font = Enum.Font.GothamBold
speedTitle.TextXAlignment = Enum.TextXAlignment.Left
y = y + 35
y = y + createToggle(tab, y, "⚡ Speed Hack", "SpeedHack", true, function(v) updateSpeedHack() end)
y = y + createSlider(tab, y, "Velocidade", "SpeedValue", 1, 300, 110, "", function(v) end)
y = y + 5
local flyTitle = Instance.new("TextLabel", tab)
flyTitle.Size = UDim2.new(1, -10, 0, 30)
flyTitle.Position = UDim2.new(0, 5, 0, y)
flyTitle.BackgroundTransparency = 1
flyTitle.Text = "🕊️ FLY"
flyTitle.TextColor3 = Color3.fromRGB(150, 200, 255)
flyTitle.TextSize = 20
flyTitle.Font = Enum.Font.GothamBold
flyTitle.TextXAlignment = Enum.TextXAlignment.Left
y = y + 35
y = y + createToggle(tab, y, "Ativar Fly (mostrar UI)", "FlyEnabled", false, function(v) toggleFlyFromHub(v) end)
y = y + 5
local movTitle2 = Instance.new("TextLabel", tab)
movTitle2.Size = UDim2.new(1, -10, 0, 30)
movTitle2.Position = UDim2.new(0, 5, 0, y)
movTitle2.BackgroundTransparency = 1
movTitle2.Text = "⚡ MOVIMENTO AVANÇADO"
movTitle2.TextColor3 = Color3.fromRGB(100, 200, 255)
movTitle2.TextSize = 20
movTitle2.Font = Enum.Font.GothamBold
movTitle2.TextXAlignment = Enum.TextXAlignment.Left
y = y + 35
y = y + createToggle(tab, y, "🦘 Infinite Jump", "InfiniteJump", true)
y = y + createToggle(tab, y, "☁️ Float", "Float", false)
y = y + 5

y = 0
tab = tabContents["VISUAL"]
local espTitle = Instance.new("TextLabel", tab)
espTitle.Size = UDim2.new(1, -10, 0, 30)
espTitle.Position = UDim2.new(0, 5, 0, y)
espTitle.BackgroundTransparency = 1
espTitle.Text = "👁️ ESP MATRIX"
espTitle.TextColor3 = Color3.fromRGB(150, 200, 255)
espTitle.TextSize = 20
espTitle.Font = Enum.Font.GothamBold
espTitle.TextXAlignment = Enum.TextXAlignment.Left
y = y + 35
y = y + createToggle(tab, y, "ESP Core", "ESPMaster", false)
y = y + createToggle(tab, y, "📦 Caixas", "ESPBoxes", true)
y = y + createToggle(tab, y, "🏷️ Nomes", "ESPNames", true)
y = y + createToggle(tab, y, "📏 Distância", "ESPDistance", true)
y = y + createToggle(tab, y, "🎨 Cor do Time", "ESPTeamColor", true)

y = 0
tab = tabContents["OUTROS"]
local extraTitle = Instance.new("TextLabel", tab)
extraTitle.Size = UDim2.new(1, -10, 0, 30)
extraTitle.Position = UDim2.new(0, 5, 0, y)
extraTitle.BackgroundTransparency = 1
extraTitle.Text = "⚙️ CONFIGURAÇÕES EXTRAS"
extraTitle.TextColor3 = Color3.fromRGB(255, 200, 200)
extraTitle.TextSize = 20
extraTitle.Font = Enum.Font.GothamBold
extraTitle.TextXAlignment = Enum.TextXAlignment.Left
y = y + 35
y = y + createToggle(tab, y, "📌 Barra Lateral Retrátil", "SidebarRetract", false)
y = y + createToggle(tab, y, "🔔 Sistema de Notificações", "Notifications", true)
y = y + createToggle(tab, y, "🎵 Efeitos Sonoros", "SoundEffects", false)

if Config.WallSystem then applyWallSystem(true) end
if Config.GodMode and player.Character then applyGodMode(player.Character, true) end
Notify("ZK HUB ULTRA carregado com sucesso!", 3)
print("ZK HUB ULTRA com Fly, God Mode e Barra Compacta iniciado.")
