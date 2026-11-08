-- ==========================================
-- ROOTSGAME SCRIPT (COMPLETO - v3.4)
-- ==========================================
local Players = game:GetService("Players")
local Workspace = game:WaitForChild("Workspace")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

GuiService.SelectedObject = nil

local SAVE_FILE = "RootsGame_Data.txt"

local DefaultConfig = {
    WeaponName = "Pumpkin Reaper Greatsword",
    AttackDistance = 18,     
    AttackCooldown = 0.15,
    HoverHeight = 10,        
    MoveSpeed = 25,          
    MinerSpeed = 25,
    WalkSpeed = 16
}

local Config = table.clone(DefaultConfig)
local savedWaypoints = {}
local isRunning = false
local lastAttackTime = 0
local isAutoClickerActive = false 
local isAutoAttackActive = false
local isHudHidden = false
local isMinimized = false
local currentWaypointTarget = nil
local isGoingToWaypoint = false
local isAutoCollectActive = false

local isMining = false
local mineTarget = nil
local minedCounts = {crystal = 0, diamond = 0, gold = 0, iron = 0, coal = 0}
local lastMineTime = 0
local MINE_DISTANCE = 5
local SAFEZONE_POS = nil
local priorities = {crystal = 5, diamond = 4, gold = 3, iron = 2, coal = 1}
local collecting = false

local isAntiAfk = false
local isInfJump = false
local isESP = false
local isNoclip = false
local isFly = false
local espFolder = nil

-- ==========================================
-- UI DE NOTIFICAÇÃO
-- ==========================================
local notifGui = Instance.new("ScreenGui")
notifGui.Name = "RootsGameNotif"
notifGui.ResetOnSpawn = false
notifGui.Parent = playerGui

local notifFrame = Instance.new("Frame")
notifFrame.Size = UDim2.new(0, 250, 0, 40)
notifFrame.Position = UDim2.new(1, -270, 1, -100)
notifFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
notifFrame.BackgroundTransparency = 1
notifFrame.Parent = notifGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 8)
notifCorner.Parent = notifFrame

local notifStroke = Instance.new("UIStroke")
notifStroke.Color = Color3.fromRGB(40, 180, 100)
notifStroke.Thickness = 2
notifStroke.Transparency = 1
notifStroke.Parent = notifFrame

local notifText = Instance.new("TextLabel")
notifText.Size = UDim2.new(1, 0, 1, 0)
notifText.BackgroundTransparency = 1
notifText.Text = "✅ Configurações Salvas!"
notifText.TextColor3 = Color3.fromRGB(40, 180, 100)
notifText.Font = Enum.Font.GothamBold
notifText.TextSize = 12
notifText.TextTransparency = 1
notifText.Parent = notifFrame

local function showNotification()
    notifFrame.BackgroundTransparency = 0.2
    notifStroke.Transparency = 0.2
    notifText.TextTransparency = 0
    task.wait(2) 
    notifFrame.BackgroundTransparency = 1
    notifStroke.Transparency = 1
    notifText.TextTransparency = 1
end

-- ==========================================
-- FUNÇÕES DE SAVE
-- ==========================================
local function saveAllData()
    if writefile then
        local dataToSave = {
            Config = Config,
            Waypoints = {},
            SafeZone = SAFEZONE_POS and {SAFEZONE_POS.X, SAFEZONE_POS.Y, SAFEZONE_POS.Z} or nil
        }
        for name, pos in pairs(savedWaypoints) do
            dataToSave.Waypoints[name] = {pos.X, pos.Y, pos.Z}
        end
        local jsonData = HttpService:JSONEncode(dataToSave)
        writefile(SAVE_FILE, jsonData)
        showNotification()
    end
end

local function loadAllData()
    if readfile and isfile and isfile(SAVE_FILE) then
        pcall(function()
            local jsonData = readfile(SAVE_FILE)
            local decoded = HttpService:JSONDecode(jsonData)
            
            if decoded.Config then
                for k, v in pairs(decoded.Config) do
                    if Config[k] ~= nil then Config[k] = v end
                end
                if Config.AttackDistance < 15 then Config.AttackDistance = 18 end
            end
            
            if decoded.Waypoints then
                for name, posArray in pairs(decoded.Waypoints) do
                    savedWaypoints[name] = Vector3.new(posArray[1], posArray[2], posArray[3])
                end
            end
            
            if decoded.SafeZone then
                SAFEZONE_POS = Vector3.new(decoded.SafeZone[1], decoded.SafeZone[2], decoded.SafeZone[3])
            end
        end)
    end
end

loadAllData()

-- ==========================================
-- UI PRINCIPAL (MENU)
-- ==========================================
local oldUI = playerGui:FindFirstChild("RootsGameUI")
if oldUI then oldUI:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RootsGameUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 380, 0, 330)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -165) 
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0, 8)
uicorner.Parent = mainFrame

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 30)
topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topStroke = Instance.new("UIStroke")
topStroke.Color = Color3.fromRGB(45, 45, 45)
topStroke.Thickness = 1
topStroke.Parent = topBar
topStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "RootsGame Script v3.4"
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 25, 0, 25)
minBtn.Position = UDim2.new(1, -60, 0, 2.5)
minBtn.BackgroundTransparency = 1
minBtn.Text = "−"
minBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -30, 0, 2.5)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = topBar

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -20, 0, 1)
divider.Position = UDim2.new(0, 10, 0, 30)
divider.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
divider.BorderSizePixel = 0
divider.Parent = mainFrame

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 100, 1, -31)
sidebar.Position = UDim2.new(0, 0, 0, 31)
sidebar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame

local sidebarCorner = Instance.new("UICorner")
sidebarCorner.CornerRadius = UDim.new(0, 8)
sidebarCorner.Parent = sidebar
local sidebarFix = Instance.new("Frame")
sidebarFix.Size = UDim2.new(1, 0, 0, 10)
sidebarFix.Position = UDim2.new(0, 0, 1, -10)
sidebarFix.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
sidebarFix.BorderSizePixel = 0
sidebarFix.Parent = sidebar

local function createSideBtn(text, y)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.Position = UDim2.new(0, 5, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = sidebar
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    return btn
end

local homeBtn = createSideBtn("Principal", 10)
homeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
homeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
local waypointBtn = createSideBtn("Waypoints", 45)
local minerBtn = createSideBtn("Miner", 80)
local variedBtn = createSideBtn("Variados", 115)
local configBtn = createSideBtn("Config", 150)

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -100, 1, -31)
contentArea.Position = UDim2.new(0, 100, 0, 31)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

-- --- CONTEÚDO HOME ---
local homePage = Instance.new("Frame")
homePage.Size = UDim2.new(1, 0, 1, 0)
homePage.BackgroundTransparency = 1
homePage.Parent = contentArea

local statusTxt = Instance.new("TextLabel")
statusTxt.Size = UDim2.new(1, -20, 0, 20)
statusTxt.Position = UDim2.new(0, 10, 0, 5)
statusTxt.BackgroundTransparency = 1
statusTxt.Text = "Status: Aguardando..."
statusTxt.TextColor3 = Color3.fromRGB(200, 220, 255)
statusTxt.Font = Enum.Font.Gotham
statusTxt.TextSize = 11
statusTxt.TextXAlignment = Enum.TextXAlignment.Left
statusTxt.Parent = homePage

local targetTxt = Instance.new("TextLabel")
targetTxt.Size = UDim2.new(1, -20, 0, 20)
targetTxt.Position = UDim2.new(0, 10, 0, 25)
targetTxt.BackgroundTransparency = 1
targetTxt.Text = "Alvo: -"
targetTxt.TextColor3 = Color3.fromRGB(150, 150, 150)
targetTxt.Font = Enum.Font.Gotham
targetTxt.TextSize = 11
targetTxt.TextXAlignment = Enum.TextXAlignment.Left
targetTxt.Parent = homePage

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -20, 0, 30)
toggleBtn.Position = UDim2.new(0, 10, 0, 50)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
toggleBtn.Text = "INICIAR VOO"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 12
toggleBtn.Parent = homePage
local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = toggleBtn

local heightLabel = Instance.new("TextLabel")
heightLabel.Size = UDim2.new(1, -20, 0, 20)
heightLabel.Position = UDim2.new(0, 10, 0, 85)
heightLabel.BackgroundTransparency = 1
heightLabel.Text = "Altura do Voo: " .. Config.HoverHeight
heightLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
heightLabel.Font = Enum.Font.GothamBold
heightLabel.TextSize = 11
heightLabel.TextXAlignment = Enum.TextXAlignment.Left
heightLabel.Parent = homePage

local heightSlider = Instance.new("TextButton")
heightSlider.Size = UDim2.new(1, -20, 0, 10)
heightSlider.Position = UDim2.new(0, 10, 0, 105)
heightSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
heightSlider.Text = ""
heightSlider.Parent = homePage
local hSliderCorner = Instance.new("UICorner")
hSliderCorner.CornerRadius = UDim.new(0, 5)
hSliderCorner.Parent = heightSlider

local heightFill = Instance.new("Frame")
heightFill.Size = UDim2.new(Config.HoverHeight/40, 0, 1, 0)
heightFill.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
heightFill.BorderSizePixel = 0
heightFill.Parent = heightSlider
local hFillCorner = Instance.new("UICorner")
hFillCorner.CornerRadius = UDim.new(0, 5)
hFillCorner.Parent = heightFill

local isDraggingHeight = false
local function updateHeight(input)
    local mouseX = input.Position.X
    local relativeX = math.clamp(mouseX - heightSlider.AbsolutePosition.X, 0, heightSlider.AbsoluteSize.X)
    local percentage = relativeX / heightSlider.AbsoluteSize.X
    local heightValue = math.floor(percentage * 40)
    if heightValue < 1 then heightValue = 1 end
    
    heightFill.Size = UDim2.new(percentage, 0, 1, 0)
    heightLabel.Text = "Altura do Voo: " .. heightValue
    Config.HoverHeight = heightValue
end

heightSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingHeight = true
        updateHeight(input)
    end
end)
heightSlider.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingHeight = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if isDraggingHeight and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateHeight(input)
    end
end)

local autoAttackBtn = Instance.new("TextButton")
autoAttackBtn.Size = UDim2.new(1, -20, 0, 30)
autoAttackBtn.Position = UDim2.new(0, 10, 0, 125) 
autoAttackBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50) 
autoAttackBtn.Text = "AUTO ATACAR: OFF"
autoAttackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoAttackBtn.Font = Enum.Font.GothamBold
autoAttackBtn.TextSize = 11
autoAttackBtn.Parent = homePage
local autoAttackCorner = Instance.new("UICorner")
autoAttackCorner.CornerRadius = UDim.new(0, 6)
autoAttackCorner.Parent = autoAttackBtn

local clickerBtn = Instance.new("TextButton")
clickerBtn.Size = UDim2.new(1, -20, 0, 30)
clickerBtn.Position = UDim2.new(0, 10, 0, 163) 
clickerBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50) 
clickerBtn.Text = "AUTO CLICK: OFF"
clickerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clickerBtn.Font = Enum.Font.GothamBold
clickerBtn.TextSize = 12
clickerBtn.Parent = homePage
local clickerCorner = Instance.new("UICorner")
clickerCorner.CornerRadius = UDim.new(0, 6)
clickerCorner.Parent = clickerBtn

local autoCollectBtn = Instance.new("TextButton")
autoCollectBtn.Size = UDim2.new(1, -20, 0, 30)
autoCollectBtn.Position = UDim2.new(0, 10, 0, 201) 
autoCollectBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50) 
autoCollectBtn.Text = "AUTO COLETA: OFF"
autoCollectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoCollectBtn.Font = Enum.Font.GothamBold
autoCollectBtn.TextSize = 11
autoCollectBtn.Parent = homePage
local autoCollectCorner = Instance.new("UICorner")
autoCollectCorner.CornerRadius = UDim.new(0, 6)
autoCollectCorner.Parent = autoCollectBtn

local hideHudBtn = Instance.new("TextButton")
hideHudBtn.Size = UDim2.new(1, -20, 0, 30)
hideHudBtn.Position = UDim2.new(0, 10, 0, 239) 
hideHudBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 150) 
hideHudBtn.Text = "OCULTAR HABILIDADES"
hideHudBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hideHudBtn.Font = Enum.Font.GothamBold
hideHudBtn.TextSize = 11
hideHudBtn.Parent = homePage
local hideHudCorner = Instance.new("UICorner")
hideHudCorner.CornerRadius = UDim.new(0, 6)
hideHudCorner.Parent = hideHudBtn

local helpTxt = Instance.new("TextLabel")
helpTxt.Size = UDim2.new(1, -20, 0, 20)
helpTxt.Position = UDim2.new(0, 10, 0, 275)
helpTxt.BackgroundTransparency = 1
helpTxt.Text = "Arraste o quadrado para o botão verde."
helpTxt.TextColor3 = Color3.fromRGB(120, 120, 120)
helpTxt.Font = Enum.Font.Gotham
helpTxt.TextSize = 9
helpTxt.Parent = homePage

-- --- CONTEÚDO WAYPOINTS ---
local waypointPage = Instance.new("Frame")
waypointPage.Size = UDim2.new(1, 0, 1, 0)
waypointPage.BackgroundTransparency = 1
waypointPage.Visible = false
waypointPage.Parent = contentArea

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(0.6, -10, 0, 30)
inputBox.Position = UDim2.new(0, 10, 0, 10)
inputBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
inputBox.PlaceholderText = "Nome do Local..."
inputBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
inputBox.Font = Enum.Font.Gotham
inputBox.TextSize = 12
inputBox.Text = ""
inputBox.Parent = waypointPage
local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 6)
inputCorner.Parent = inputBox

local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(0.4, -10, 0, 30)
saveBtn.Position = UDim2.new(0.6, 0, 0, 10)
saveBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 180)
saveBtn.Text = "Salvar Local"
saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 12
saveBtn.Parent = waypointPage
local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0, 6)
saveCorner.Parent = saveBtn

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -100)
scrollFrame.Position = UDim2.new(0, 10, 0, 50)
scrollFrame.BackgroundTransparency = 1
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 2
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
scrollFrame.Parent = waypointPage

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
end)

local function updateWaypointList()
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for name, pos in pairs(savedWaypoints) do
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, 0, 0, 30)
        item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        item.Parent = scrollFrame
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 6)
        itemCorner.Parent = item

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -80, 1, 0)
        nameLabel.Position = UDim2.new(0, 10, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = item

        local goBtn = Instance.new("TextButton")
        goBtn.Size = UDim2.new(0, 50, 0, 24)
        goBtn.Position = UDim2.new(1, -80, 0.5, -12)
        goBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
        goBtn.Text = "Goto"
        goBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        goBtn.Font = Enum.Font.GothamBold
        goBtn.TextSize = 11
        goBtn.Parent = item
        local goCorner = Instance.new("UICorner")
        goCorner.CornerRadius = UDim.new(0, 4)
        goCorner.Parent = goBtn

        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0, 24, 0, 24)
        delBtn.Position = UDim2.new(1, -24, 0.5, -12)
        delBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        delBtn.Text = "X"
        delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 11
        delBtn.Parent = item
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 4)
        delCorner.Parent = delBtn

        goBtn.MouseButton1Click:Connect(function()
            currentWaypointTarget = pos
            isGoingToWaypoint = true
            isRunning = false
            toggleBtn.Text = "INICIAR VOO"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
        end)

        delBtn.MouseButton1Click:Connect(function()
            savedWaypoints[name] = nil
            updateWaypointList()
            saveAllData() 
        end)
    end
end

saveBtn.MouseButton1Click:Connect(function()
    local name = inputBox.Text
    if name ~= "" then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            savedWaypoints[name] = hrp.Position
            inputBox.Text = ""
            updateWaypointList()
            saveAllData() 
        end
    end
end)

-- --- CONTEÚDO MINER ---
local minerPage = Instance.new("Frame")
minerPage.Size = UDim2.new(1, 0, 1, 0)
minerPage.BackgroundTransparency = 1
minerPage.Visible = false
minerPage.Parent = contentArea

local statusMinerTxt = Instance.new("TextLabel")
statusMinerTxt.Size = UDim2.new(1, -20, 0, 20)
statusMinerTxt.Position = UDim2.new(0, 10, 0, 10)
statusMinerTxt.BackgroundTransparency = 1
statusMinerTxt.Text = "Status: Parado"
statusMinerTxt.TextColor3 = Color3.fromRGB(200, 220, 255)
statusMinerTxt.Font = Enum.Font.Gotham
statusMinerTxt.TextSize = 11
statusMinerTxt.TextXAlignment = Enum.TextXAlignment.Left
statusMinerTxt.Parent = minerPage

local targetMinerTxt = Instance.new("TextLabel")
targetMinerTxt.Size = UDim2.new(1, -20, 0, 20)
targetMinerTxt.Position = UDim2.new(0, 10, 0, 30)
targetMinerTxt.BackgroundTransparency = 1
targetMinerTxt.Text = "Minério Alvo: -"
targetMinerTxt.TextColor3 = Color3.fromRGB(150, 150, 150)
targetMinerTxt.Font = Enum.Font.Gotham
targetMinerTxt.TextSize = 11
targetMinerTxt.TextXAlignment = Enum.TextXAlignment.Left
targetMinerTxt.Parent = minerPage

local toggleMinerBtn = Instance.new("TextButton")
toggleMinerBtn.Size = UDim2.new(1, -20, 0, 30)
toggleMinerBtn.Position = UDim2.new(0, 10, 0, 60)
toggleMinerBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
toggleMinerBtn.Text = "INICIAR MINERAÇÃO"
toggleMinerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleMinerBtn.Font = Enum.Font.GothamBold
toggleMinerBtn.TextSize = 12
toggleMinerBtn.Parent = minerPage
local minerBtnCorner = Instance.new("UICorner")
minerBtnCorner.CornerRadius = UDim.new(0, 6)
minerBtnCorner.Parent = toggleMinerBtn

local safezoneBtn = Instance.new("TextButton")
safezoneBtn.Size = UDim2.new(1, -20, 0, 30)
safezoneBtn.Position = UDim2.new(0, 10, 0, 98)
safezoneBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 180)
safezoneBtn.Text = "DEFINIR SAFEZONE"
safezoneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
safezoneBtn.Font = Enum.Font.GothamBold
safezoneBtn.TextSize = 12
safezoneBtn.Parent = minerPage
local safezoneCorner = Instance.new("UICorner")
safezoneCorner.CornerRadius = UDim.new(0, 6)
safezoneCorner.Parent = safezoneBtn

local minerStatsTxt = Instance.new("TextLabel")
minerStatsTxt.Size = UDim2.new(1, -20, 0, 80)
minerStatsTxt.Position = UDim2.new(0, 10, 0, 136)
minerStatsTxt.BackgroundTransparency = 1
minerStatsTxt.Text = "Crystal: 0 | Diamond: 0\nGold: 0 | Iron: 0 | Coal: 0"
minerStatsTxt.TextColor3 = Color3.fromRGB(150, 150, 150)
minerStatsTxt.Font = Enum.Font.Gotham
minerStatsTxt.TextSize = 10
minerStatsTxt.TextXAlignment = Enum.TextXAlignment.Left
minerStatsTxt.TextYAlignment = Enum.TextYAlignment.Top
minerStatsTxt.Parent = minerPage

-- --- CONTEÚDO VARIADOS ---
local variedPage = Instance.new("Frame")
variedPage.Size = UDim2.new(1, 0, 1, 0)
variedPage.BackgroundTransparency = 1
variedPage.Visible = false
variedPage.Parent = contentArea

local function createVarBtn(text, posX, posY)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.48, 0, 0, 30)
    btn.Position = UDim2.new(posX, 0, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = variedPage
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    return btn
end

local antiAfkBtn = createVarBtn("Anti-AFK", 0.02, 10)
local infJumpBtn = createVarBtn("Inf Jump", 0.52, 10)
local espBtn = createVarBtn("ESP", 0.02, 50)
local noclipBtn = createVarBtn("Noclip", 0.52, 50)
local flyBtn = createVarBtn("Fly", 0.02, 90)
local serverHopBtn = createVarBtn("Server Hop", 0.52, 90)

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -20, 0, 20)
speedLabel.Position = UDim2.new(0, 10, 0, 130)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Velocidade: " .. Config.WalkSpeed
speedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextSize = 11
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = variedPage

local speedSlider = Instance.new("TextButton")
speedSlider.Size = UDim2.new(1, -20, 0, 10)
speedSlider.Position = UDim2.new(0, 10, 0, 150)
speedSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
speedSlider.Text = ""
speedSlider.Parent = variedPage
local sliderCorner = Instance.new("UICorner")
sliderCorner.CornerRadius = UDim.new(0, 5)
sliderCorner.Parent = speedSlider

local speedFill = Instance.new("Frame")
speedFill.Size = UDim2.new(0, 0, 1, 0)
speedFill.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
speedFill.BorderSizePixel = 0
speedFill.Parent = speedSlider
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 5)
fillCorner.Parent = speedFill

local isDraggingSlider = false
local function updateSpeed(input)
    local mouseX = input.Position.X
    local relativeX = math.clamp(mouseX - speedSlider.AbsolutePosition.X, 0, speedSlider.AbsoluteSize.X)
    local percentage = relativeX / speedSlider.AbsoluteSize.X
    local speedValue = math.floor(16 + (percentage * 184))
    
    speedFill.Size = UDim2.new(percentage, 0, 1, 0)
    speedLabel.Text = "Velocidade: " .. speedValue
    Config.WalkSpeed = speedValue
    
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = speedValue end
    end
end

speedSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = true
        updateSpeed(input)
    end
end)
speedSlider.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSpeed(input)
    end
end)

local function toggleUI(btn, state)
    btn.Text = btn.Text:gsub(state and ": OFF" or ": ON", state and ": ON" or ": OFF")
    btn.BackgroundColor3 = state and Color3.fromRGB(40, 180, 100) or Color3.fromRGB(50, 50, 50)
end

antiAfkBtn.MouseButton1Click:Connect(function()
    isAntiAfk = not isAntiAfk
    toggleUI(antiAfkBtn, isAntiAfk)
    if isAntiAfk then
        local vu = game:GetService("VirtualUser")
        player.Idled:Connect(function()
            if isAntiAfk then
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end
        end)
    end
end)

infJumpBtn.MouseButton1Click:Connect(function()
    isInfJump = not isInfJump
    toggleUI(infJumpBtn, isInfJump)
end)

UserInputService.JumpRequest:Connect(function()
    if isInfJump then
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

espBtn.MouseButton1Click:Connect(function()
    isESP = not isESP
    toggleUI(espBtn, isESP)
    if isESP then
        espFolder = Instance.new("Folder", Workspace)
        espFolder.Name = "ESP_Highlights"
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not obj:FindFirstChild("ESP_Highlight") then
                local h = Instance.new("Highlight")
                h.Name = "ESP_Highlight"
                h.FillColor = Color3.fromRGB(255, 0, 0)
                h.OutlineColor = Color3.fromRGB(255, 255, 255)
                h.Parent = obj
            end
        end
    else
        if espFolder then espFolder:Destroy() end
        for _, obj in pairs(Workspace:GetDescendants()) do
            local h = obj:FindFirstChild("ESP_Highlight")
            if h then h:Destroy() end
        end
    end
end)

noclipBtn.MouseButton1Click:Connect(function()
    isNoclip = not isNoclip
    toggleUI(noclipBtn, isNoclip)
end)

RunService.Stepped:Connect(function()
    if isNoclip then
        local char = player.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
    end
end)

flyBtn.MouseButton1Click:Connect(function()
    isFly = not isFly
    toggleUI(flyBtn, isFly)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if isFly then
        if hrp then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "Fly_BV"
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Parent = hrp
        end
    else
        if hrp then
            local bv = hrp:FindFirstChild("Fly_BV")
            if bv then bv:Destroy() end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if isFly then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        local bv = hrp and hrp:FindFirstChild("Fly_BV")
        if hrp and cam and bv then
            local moveDir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
            
            bv.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * 50 or Vector3.zero
        end
    end
end)

serverHopBtn.MouseButton1Click:Connect(function()
    serverHopBtn.Text = "Procurando..."
    local success, servers = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if success and servers and servers.data then
        for _, server in pairs(servers.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                break
            end
        end
    end
    serverHopBtn.Text = "Server Hop: OFF"
end)

-- --- CONTEÚDO CONFIG ---
local configPage = Instance.new("Frame")
configPage.Size = UDim2.new(1, 0, 1, 0)
configPage.BackgroundTransparency = 1
configPage.Visible = false
configPage.Parent = contentArea

local saveConfigBtn = Instance.new("TextButton")
saveConfigBtn.Size = UDim2.new(1, -20, 0, 35)
saveConfigBtn.Position = UDim2.new(0, 10, 0, 10)
saveConfigBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
saveConfigBtn.Text = "Save Config  💾"
saveConfigBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveConfigBtn.Font = Enum.Font.GothamBold
saveConfigBtn.TextSize = 13
saveConfigBtn.Parent = configPage
local saveConfigCorner = Instance.new("UICorner")
saveConfigCorner.CornerRadius = UDim.new(0, 6)
saveConfigCorner.Parent = saveConfigBtn

local resetConfigBtn = Instance.new("TextButton")
resetConfigBtn.Size = UDim2.new(1, -20, 0, 35)
resetConfigBtn.Position = UDim2.new(0, 10, 0, 55)
resetConfigBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
resetConfigBtn.Text = "Reset Defaults  ↺"
resetConfigBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resetConfigBtn.Font = Enum.Font.GothamBold
resetConfigBtn.TextSize = 13
resetConfigBtn.Parent = configPage
local resetConfigCorner = Instance.new("UICorner")
resetConfigCorner.CornerRadius = UDim.new(0, 6)
resetConfigCorner.Parent = resetConfigBtn

local statusConfigTxt = Instance.new("TextLabel")
statusConfigTxt.Size = UDim2.new(1, -20, 0, 20)
statusConfigTxt.Position = UDim2.new(0, 10, 0, 100)
statusConfigTxt.BackgroundTransparency = 1
statusConfigTxt.Text = "Status: Pronto."
statusConfigTxt.TextColor3 = Color3.fromRGB(150, 150, 150)
statusConfigTxt.Font = Enum.Font.Gotham
statusConfigTxt.TextSize = 10
statusConfigTxt.TextXAlignment = Enum.TextXAlignment.Left
statusConfigTxt.Parent = configPage

saveConfigBtn.MouseButton1Click:Connect(function()
    saveAllData()
    statusConfigTxt.Text = "Status: Configurações salvas com sucesso!"
    statusConfigTxt.TextColor3 = Color3.fromRGB(40, 180, 100)
end)

resetConfigBtn.MouseButton1Click:Connect(function()
    Config = table.clone(DefaultConfig)
    saveAllData()
    statusConfigTxt.Text = "Status: Configurações resetadas!"
    statusConfigTxt.TextColor3 = Color3.fromRGB(40, 180, 100)
end)

-- ==========================================
-- LÓGICA DE TROCA DE ABAS
-- ==========================================
local function setTab(activeBtn, activePage)
    local tabs = {
        [homeBtn] = homePage,
        [waypointBtn] = waypointPage,
        [minerBtn] = minerPage,
        [variedBtn] = variedPage,
        [configBtn] = configPage,
    }
    
    for btn, page in pairs(tabs) do
        if btn == activeBtn then
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            page.Visible = true
        else
            btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
            page.Visible = false
        end
    end
end

homeBtn.MouseButton1Click:Connect(function() setTab(homeBtn, homePage) end)
waypointBtn.MouseButton1Click:Connect(function() 
    setTab(waypointBtn, waypointPage)
    updateWaypointList()
end)
minerBtn.MouseButton1Click:Connect(function() setTab(minerBtn, minerPage) end)
variedBtn.MouseButton1Click:Connect(function() setTab(variedBtn, variedPage) end)
configBtn.MouseButton1Click:Connect(function() setTab(configBtn, configPage) end)

-- ==========================================
-- FUNÇÕES DOS BOTÕES HOME
-- ==========================================
toggleBtn.MouseButton1Click:Connect(function()
    isRunning = not isRunning
    if isRunning then
        isGoingToWaypoint = false
        toggleBtn.Text = "PARAR VOO"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    else
        toggleBtn.Text = "INICIAR VOO"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
        statusTxt.Text = "Status: Parado"
        targetTxt.Text = "Alvo: -"
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bp = hrp:FindFirstChild("AutoHover")
            if bp then bp:Destroy() end 
            local bv = hrp:FindFirstChild("AutoFly")
            if bv then bv:Destroy() end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then 
                hum.WalkSpeed = Config.WalkSpeed
                hum.PlatformStand = false
            end
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end)

autoAttackBtn.MouseButton1Click:Connect(function()
    isAutoAttackActive = not isAutoAttackActive
    if isAutoAttackActive then
        autoAttackBtn.Text = "AUTO ATACAR: ON"
        autoAttackBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
    else
        autoAttackBtn.Text = "AUTO ATACAR: OFF"
        autoAttackBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    end
end)

clickerBtn.MouseButton1Click:Connect(function()
    isAutoClickerActive = not isAutoClickerActive
    if isAutoClickerActive then
        clickerBtn.Text = "AUTO CLICK: ON"
        clickerBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
        targetBox.BackgroundColor3 = Color3.fromRGB(0, 255, 0) 
    else
        clickerBtn.Text = "AUTO CLICK: OFF"
        clickerBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
        targetBox.BackgroundColor3 = Color3.fromRGB(255, 0, 0) 
    end
end)

autoCollectBtn.MouseButton1Click:Connect(function()
    isAutoCollectActive = not isAutoCollectActive
    if isAutoCollectActive then
        autoCollectBtn.Text = "AUTO COLETA: ON"
        autoCollectBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
    else
        autoCollectBtn.Text = "AUTO COLETA: OFF"
        autoCollectBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
end)

hideHudBtn.MouseButton1Click:Connect(function()
    isHudHidden = not isHudHidden
    local hotbar = playerGui:FindFirstChild("Hotbar")
    if hotbar then hotbar.Enabled = not isHudHidden end
    local touchGui = playerGui:FindFirstChild("TouchGui")
    if touchGui then
        local touchFrame = touchGui:FindFirstChild("TouchControlFrame")
        if touchFrame then touchFrame.Visible = not isHudHidden end
    end
    hideHudBtn.Text = isHudHidden and "MOSTRAR HABILIDADES" or "OCULTAR HABILIDADES"
end)

toggleMinerBtn.MouseButton1Click:Connect(function()
    isMining = not isMining
    if isMining then
        toggleMinerBtn.Text = "PARAR MINERAÇÃO"
        toggleMinerBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        statusMinerTxt.Text = "Status: Procurando minérios..."
        statusMinerTxt.TextColor3 = Color3.fromRGB(40, 180, 100)
    else
        toggleMinerBtn.Text = "INICIAR MINERAÇÃO"
        toggleMinerBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
        statusMinerTxt.Text = "Status: Parado"
        statusMinerTxt.TextColor3 = Color3.fromRGB(200, 220, 255)
        targetMinerTxt.Text = "Minério Alvo: -"
        mineTarget = nil
        local char = player.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end)

safezoneBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        SAFEZONE_POS = hrp.Position
        saveAllData()
        statusMinerTxt.Text = "Status: Safezone definida!"
        statusMinerTxt.TextColor3 = Color3.fromRGB(40, 180, 100)
    end
end)

closeBtn.MouseButton1Click:Connect(function() 
    saveAllData() 
    screenGui:Destroy() 
end)

minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        mainFrame.Size = UDim2.new(0, 380, 0, 30)
        sidebar.Visible = false
        contentArea.Visible = false
        divider.Visible = false
        minBtn.Text = "+"
    else
        mainFrame.Size = UDim2.new(0, 380, 0, 330)
        sidebar.Visible = true
        contentArea.Visible = true
        divider.Visible = true
        minBtn.Text = "−"
    end
end)

-- ==========================================
-- ALVO FÍSICO
-- ==========================================
local targetBox = Instance.new("Frame")
targetBox.Name = "ClickTarget"
targetBox.Size = UDim2.new(0, 40, 0, 40) 
targetBox.Position = UDim2.new(0.5, 0, 0.8, 0) 
targetBox.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
targetBox.BackgroundTransparency = 0.5 
targetBox.Active = true
targetBox.Parent = screenGui

local targetCorner = Instance.new("UICorner")
targetCorner.CornerRadius = UDim.new(0, 8)
targetCorner.Parent = targetBox

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, 0, 1, 0)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "Alvo"
targetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
targetLabel.Font = Enum.Font.GothamBold
targetLabel.TextSize = 9
targetLabel.Parent = targetBox

local dragging = false
local dragStart, startPos

targetBox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = targetBox.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

targetBox.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        targetBox.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ==========================================
-- FUNÇÕES DE DETECÇÃO E LOOPS
-- ==========================================
local function getDungeonEnemy()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest, shortest = nil, math.huge
    
    local animalLive = Workspace:FindFirstChild("Animal_Live")
    local aggressorsFolder = animalLive and animalLive:FindFirstChild("Aggressors")
    if aggressorsFolder then
        for _, folder in pairs(aggressorsFolder:GetChildren()) do
            for _, child in pairs(folder:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    if not child.Name:find("FX") and not child.Name:find("Sound") then
                        local enemyPos
                        if child:IsA("Model") then
                            local highestY = -math.huge
                            enemyPos = child:GetPivot().Position
                            for _, p in pairs(child:GetDescendants()) do
                                if p:IsA("BasePart") then
                                    if p.Position.Y > highestY then
                                        highestY = p.Position.Y
                                        enemyPos = p.Position
                                    end
                                end
                            end
                        else
                            enemyPos = child.Position
                        end

                        local dist = (hrp.Position - enemyPos).Magnitude
                        if dist < shortest then
                            shortest = dist
                            nearest = { object = child, pos = enemyPos, name = child.Name }
                        end
                    end
                end
            end
        end
    end
    return nearest
end

local function getClosestOre()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local folder = Workspace:FindFirstChild("Ore_Live")
    if not folder then return nil end
    
    local nearest, shortest = nil, math.huge
    for _, node in ipairs(folder:GetDescendants()) do
        local name = string.lower(node.Name):gsub("[%s_%-]", "")
        local kind = name:match("^(%a+)orenode")
        
        if kind and priorities[kind] then
            local part = node:IsA("BasePart") and node or node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart")
            if part and part.Transparency < 1 then
                local dist = (hrp.Position - part.Position).Magnitude
                if dist < shortest then 
                    shortest = dist
                    nearest = { object = node, part = part, pos = part.Position, kind = kind }
                end
            end
        end
    end
    return nearest
end

local function TryCollect()
    if collecting then return end
    collecting = true
    task.spawn(function()
        task.wait(0.5) 
        for _, gui in pairs(playerGui:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                local txt = ""
                if gui:IsA("TextButton") then txt = string.upper(gui.Text) end
                if txt:find("COLETAR") or txt:find("PEGAR") or txt:find("E") then
                    pcall(function() gui:Fire("MouseButton1Click", true) end)
                    break
                end
            end
        end
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
        task.wait(1)
        collecting = false
    end)
end

task.spawn(function()
    while task.wait(30) do
        saveAllData()
    end
end)

task.spawn(function()
    while task.wait(4) do 
        if isAutoClickerActive then
            local absPos = targetBox.AbsolutePosition
            local absSize = targetBox.AbsoluteSize
            local cx = absPos.X + (absSize.X / 2)
            local cy = absPos.Y + (absSize.Y / 2)

            pcall(function()
                VirtualInputManager:SendMouseMoveEvent(cx, cy, game)
                task.wait(0.2) 
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait(0.2) 
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= Config.WalkSpeed and not isMining and not isRunning then
            hum.WalkSpeed = Config.WalkSpeed
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if isAutoCollectActive then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.2) do
        if isAutoAttackActive then
            local char = player.Character
            if char then
                local tool = char:FindFirstChild(Config.WeaponName) or char:FindFirstChildOfClass("Tool")
                if tool then
                    local handle = tool:FindFirstChild("Handle")
                    if handle then 
                        handle.Size = Vector3.new(15, 15, 15)
                        handle.CanCollide = false
                    end
                    pcall(function() tool:Activate() end)
                end
            end
        end
    end
end)

-- Loop Principal (Farm / Mineração)
task.spawn(function()
    while task.wait(0.15) do 
        if isMining then
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if humanoid and hrp then
                local ore = getClosestOre()
                
                if ore then
                    mineTarget = ore
                    statusMinerTxt.Text = "Status: Voando para " .. ore.kind
                    targetMinerTxt.Text = "Minério Alvo: " .. ore.object.Name
                    
                    local dist = (hrp.Position - ore.pos).Magnitude
                    
                    if dist > MINE_DISTANCE then
                        humanoid.PlatformStand = true
                        for _, part in pairs(char:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                        
                        local bp = hrp:FindFirstChild("AutoHover")
                        if bp then bp:Destroy() end
                        
                        local bv = hrp:FindFirstChild("AutoFly")
                        if not bv then
                            bv = Instance.new("BodyVelocity")
                            bv.Name = "AutoFly"
                            bv.MaxForce = Vector3.new(50000, 50000, 50000)
                            bv.Parent = hrp
                        end
                        
                        local direction = (ore.pos - hrp.Position).Unit
                        bv.Velocity = direction * Config.MinerSpeed
                        
                    else
                        humanoid.PlatformStand = false
                        local bv = hrp:FindFirstChild("AutoFly")
                        if bv then bv:Destroy() end
                        
                        for _, part in pairs(char:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = true end
                        end
                        
                        humanoid.WalkSpeed = 0
                        humanoid:MoveTo(hrp.Position)
                        hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(ore.pos.X, ore.pos.Y, ore.pos.Z))
                        
                        if tick() - lastMineTime > 0.5 then
                            lastMineTime = tick()
                            local tool = char:FindFirstChildOfClass("Tool")
                            if tool and tool.Name:lower():find("pick") then
                                local handle = tool:FindFirstChild("Handle")
                                if handle then handle.Size = Vector3.new(8, 8, 8) end
                                
                                tool:Activate()
                                minedCounts[ore.kind] = (minedCounts[ore.kind] or 0) + 1
                                minerStatsTxt.Text = string.format("Crystal: %d | Diamond: %d\nGold: %d | Iron: %d | Coal: %d", 
                                    minedCounts.crystal, minedCounts.diamond, minedCounts.gold, minedCounts.iron, minedCounts.coal)
                                TryCollect()
                            end
                        end
                    end
                    continue
                else
                    statusMinerTxt.Text = "Status: Nenhum minério encontrado."
                    targetMinerTxt.Text = "Minério Alvo: -"
                    
                    humanoid.PlatformStand = false
                    local bv = hrp:FindFirstChild("AutoFly")
                    if bv then bv:Destroy() end
                    
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = true end
                    end

                    if SAFEZONE_POS then
                        local distSafe = (hrp.Position - SAFEZONE_POS).Magnitude
                        if distSafe > 3 then
                            humanoid.WalkSpeed = Config.MinerSpeed
                            humanoid:MoveTo(SAFEZONE_POS)
                        else
                            humanoid.WalkSpeed = Config.WalkSpeed
                            humanoid:MoveTo(hrp.Position)
                        end
                    end
                    continue
                end
            end
        end

        if not isRunning then continue end
        if isGoingToWaypoint then continue end 

        local char = player.Character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not hrp then continue end

        local enemy = getDungeonEnemy()
        local bp = hrp:FindFirstChild("AutoHover")
        local bv = hrp:FindFirstChild("AutoFly")

        humanoid.PlatformStand = true 
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end

        if enemy then
            statusTxt.Text = "Status: Voando para o Alvo"
            targetTxt.Text = "Alvo: " .. tostring(enemy.name)
            
            local dist = (hrp.Position - enemy.pos).Magnitude
            
            if dist > Config.AttackDistance then
                if bp then bp:Destroy() end
                if not bv then
                    bv = Instance.new("BodyVelocity")
                    bv.Name = "AutoFly"
                    bv.MaxForce = Vector3.new(50000, 50000, 50000)
                    bv.Parent = hrp
                end
                local direction = (enemy.pos - hrp.Position).Unit
                bv.Velocity = direction * Config.MoveSpeed 
            else
                if bv then bv:Destroy() end
                if not bp then
                    bp = Instance.new("BodyPosition")
                    bp.Name = "AutoHover"
                    bp.MaxForce = Vector3.new(50000, 50000, 50000)
                    bp.P = 10000
                    bp.D = 1000
                    bp.Parent = hrp
                end
                bp.Position = Vector3.new(hrp.Position.X, enemy.pos.Y + Config.HoverHeight, hrp.Position.Z)
            end
            
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            
            local lookAt = CFrame.new(hrp.Position, Vector3.new(enemy.pos.X, hrp.Position.Y, enemy.pos.Z))
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, lookAt.Rotation.Y, 0)
            
            if dist <= Config.AttackDistance then
                local tool = char:FindFirstChild(Config.WeaponName) or char:FindFirstChildOfClass("Tool")
                if tool then 
                    local handle = tool:FindFirstChild("Handle")
                    if handle then 
                        handle.Size = Vector3.new(12, 12, 12)
                        handle.CanCollide = false 
                    end
                    pcall(function() tool:Activate() end) 
                end
            end
        else
            statusTxt.Text = "Status: Aguardando Inimigo..."
            targetTxt.Text = "Alvo: -"
            if bv then bv:Destroy() end
            if hrp then
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end
end)

-- ⭐ Loop do Waypoint ⭐
task.spawn(function()
    while task.wait(0.1) do
        if not isGoingToWaypoint or not currentWaypointTarget then continue end
        local char = player.Character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not hrp then continue end

        local distHorizontal = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(currentWaypointTarget.X, 0, currentWaypointTarget.Z)).Magnitude
        
        if distHorizontal > 3 then
            humanoid.PlatformStand = true 

            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            
            local bv = hrp:FindFirstChild("AutoFly")
            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.Name = "AutoFly"
                bv.MaxForce = Vector3.new(50000, 50000, 50000)
                bv.Parent = hrp
            end
            
            local direction = (currentWaypointTarget - hrp.Position).Unit
            bv.Velocity = direction * Config.MoveSpeed 
            
            hrp.AssemblyAngularVelocity = Vector3.zero
            local lookAt = CFrame.new(hrp.Position, Vector3.new(currentWaypointTarget.X, hrp.Position.Y, currentWaypointTarget.Z))
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, lookAt.Rotation.Y, 0)
        else
            local bv = hrp:FindFirstChild("AutoFly")
            if bv then bv:Destroy() end
            local bp = hrp:FindFirstChild("AutoHover")
            if bp then bp:Destroy() end
            
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end

            humanoid.PlatformStand = false
            humanoid.WalkSpeed = Config.WalkSpeed
            
            hrp.CFrame = CFrame.new(hrp.Position.X, currentWaypointTarget.Y + 3, hrp.Position.Z)
            
            isGoingToWaypoint = false
            currentWaypointTarget = nil
        end
    end
end)

-- Arrastar HUD
local draggingHud = false
local dragHudStart, startHudPos

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingHud = true
        dragHudStart = input.Position
        startHudPos = mainFrame.Position
    end
end)

topBar.InputChanged:Connect(function(input)
    if draggingHud and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragHudStart
        mainFrame.Position = UDim2.new(startHudPos.X.Scale, startHudPos.X.Offset + delta.X, startHudPos.Y.Scale, startHudPos.Y.Offset + delta.Y)
    end
end)

topBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingHud = false
    end
end)

print("⚔️ RootsGame Script v3.4 Carregado (Com Barra de Altura + Auto Atacar)!")
