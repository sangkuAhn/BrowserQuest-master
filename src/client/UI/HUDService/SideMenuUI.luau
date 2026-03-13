--!strict
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(Shared:WaitForChild("Data"):WaitForChild("UITheme"))
local Logger = require(Shared:WaitForChild("Core"):WaitForChild("Logger"))
local ServiceConfig = require(Shared:WaitForChild("Data"):WaitForChild("ServiceConfig"))
local UIEvents = require(Shared:WaitForChild("Core"):WaitForChild("UIEvents"))
local Framework = require(Shared:WaitForChild("Core"):WaitForChild("Framework")) -- [추가] 🚩
local ResponsiveManager = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Core"):WaitForChild("ResponsiveManager")) 

local SideMenuUI = {}

-- [제거] UIMapping 테이블 하드코딩 제거 (Registry 완전 연동) 🚩 Phase 4

-- [반응형 상수] 🚩
local PC_PANEL_SIZE = UDim2.new(0, 165, 0.65, 0) -- [상태] 가변 너비로 전환될 예정 🚩
local PC_PANEL_POS  = UDim2.new(1, -15, 0, 180) -- [상향] 기본값, 이후 Minimap 연동 🚩
local MOBILE_PANEL_SIZE = UDim2.new(0, 140, 0, 50) -- [수정] 모바일 최적화 🚩
local MOBILE_PANEL_POS  = UDim2.new(1, -10, 1, -85) -- [수정] 우측 하단 (QuickAccess 회피) 🚩

-- 변수
local currentOpenPopup: string? = nil
local menuButtons: {[string]: TextButton} = {}
local isMenuExpanded = false
local currentMode = "PC"
local isCompactMode = false -- [추가] 🚩
local sidePanelFrame: Frame?
local menuContainer: ScrollingFrame?
local menuExpandIcon: TextLabel?
local _titleIcon: TextLabel?
local sideMenuGui: ScreenGui?
local minimapUI: any = nil -- [추가] 업밸류 선언 🚩

function SideMenuUI.Init()
    -- 필요시 초기화 로직 구현
end

function SideMenuUI.Create(parent: ScreenGui)
    if pgui:FindFirstChild("SideMenuGui") then return end

    sideMenuGui = Instance.new("ScreenGui")
    local screenGui = sideMenuGui :: ScreenGui
    screenGui.Name = "SideMenuGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true 
    screenGui.DisplayOrder = 20
    screenGui.Parent = pgui

    isMenuExpanded = true
    currentMode = ResponsiveManager.GetMode() -- 초기 모드 설정 🚩

    -- [1] 메인 사이드 패널 (Glassmorphism 효과)
    local panel = Instance.new("Frame")
    panel.Name = "SidePanel"
    
    -- 초기 모드에 따른 배치 🚩
    if currentMode == "Mobile" then
        panel.Size = MOBILE_PANEL_SIZE
        panel.Position = MOBILE_PANEL_POS
        panel.AnchorPoint = Vector2.new(0.5, 1)
    else
        panel.Size = PC_PANEL_SIZE
        panel.Position = PC_PANEL_POS
        panel.AnchorPoint = Vector2.new(1, 0)
    end
    
    panel.ClipsDescendants = true
    panel.BackgroundColor3 = UITheme.Colors.Main
    panel.BackgroundTransparency = 1 
    panel.BorderSizePixel = 0
    panel.ZIndex = 10 -- [추가] 🚩
    panel.Parent = screenGui
    sidePanelFrame = panel

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UITheme.Shapes.CornerRadius
    panelCorner.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = UITheme.Colors.Accent
    panelStroke.Thickness = 1.5
    panelStroke.Transparency = 1 -- [수정] 외곽선 투명화 🚩
    panelStroke.Parent = panel

    local header = Instance.new("TextButton")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = UITheme.Colors.Main -- [추가] 헤더만 박스 스타일 🚩
    header.BackgroundTransparency = 0.2
    header.Text = ""
    header.Parent = panel

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UITheme.Shapes.CornerRadius
    headerCorner.Parent = header

    local headerStroke = Instance.new("UIStroke")
    headerStroke.Color = UITheme.Colors.Accent
    headerStroke.Thickness = 1.5
    headerStroke.Transparency = 0.5
    headerStroke.Parent = header

    local headerPad = Instance.new("UIPadding")
    headerPad.PaddingLeft = UDim.new(0, 12)
    headerPad.PaddingRight = UDim.new(0, 12)
    headerPad.Parent = header

    local tIcon = Instance.new("TextLabel")
    tIcon.Size = UDim2.new(0, 24, 0, 24)
    tIcon.Position = UDim2.new(0, 0, 0.5, 0)
    tIcon.AnchorPoint = Vector2.new(0, 0.5)
    tIcon.BackgroundTransparency = 1
    tIcon.Text = "≡"
    tIcon.TextColor3 = UITheme.Colors.Accent
    tIcon.TextSize = 20
    tIcon.Font = UITheme.Font.Bold
    tIcon.Parent = header
    _titleIcon = tIcon

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(0, 80, 0, 24)
    titleText.Position = UDim2.new(0, 32, 0.5, 0)
    titleText.AnchorPoint = Vector2.new(0, 0.5)
    titleText.BackgroundTransparency = 1
    titleText.Text = "MENU"
    titleText.TextColor3 = UITheme.Colors.Text
    titleText.TextSize = 14
    titleText.Font = UITheme.Font.Title
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = header

    local expandIcon = Instance.new("TextLabel")
    expandIcon.Size = UDim2.new(0, 24, 0, 24) -- 크기 축소 🚩
    expandIcon.Position = UDim2.new(1, 0, 0.5, -1) -- 수직 위치 미세 보정 🚩
    expandIcon.AnchorPoint = Vector2.new(1, 0.5)
    expandIcon.BackgroundTransparency = 1
    expandIcon.Text = "▲"
    expandIcon.TextColor3 = UITheme.Colors.TextSub
    expandIcon.TextSize = 20 -- [수정] 36에서 20으로 축소하여 텍스트와 균형 맞춤 🚩
    expandIcon.Font = UITheme.Font.Bold
    expandIcon.Parent = header
    menuExpandIcon = expandIcon

    local container = Instance.new("ScrollingFrame")
    container.Name = "MenuContainer"
    container.Size = UDim2.new(1, 0, 1, -48 - 12)
    container.Position = UDim2.new(0, 0, 0, 48)
    container.BackgroundTransparency = 1
    container.ScrollBarThickness = 4
    container.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
    container.CanvasSize = UDim2.new(0, 0, 0, 0)
    container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    container.Visible = true
    container.BorderSizePixel = 0
    container.Parent = panel
    menuContainer = container

    local grid = Instance.new("UIGridLayout")
    -- 초기 그리드 설정 🚩
    if currentMode == "Mobile" then
        grid.CellSize = UDim2.new(0, 50, 0, 50)
        grid.FillDirection = Enum.FillDirection.Horizontal
    else
        grid.CellSize = UDim2.new(0, 46, 0, 58) -- [수정] 48 -> 46으로 축소하여 여백 확보 🚩
        grid.FillDirection = Enum.FillDirection.Horizontal
    end
    grid.CellPadding = UDim2.new(0, 3, 0, 8)
    grid.StartCorner = Enum.StartCorner.TopRight 
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Right 
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = container

    local padding = Instance.new("UIPadding")
    padding.PaddingTop    = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.PaddingLeft   = UDim.new(0, 5)
    padding.PaddingRight  = UDim.new(0, 5)
    padding.Parent = container

    header.MouseButton1Click:Connect(SideMenuUI.ToggleMenu)

    -- [반응형 신호 구독] 🚩
    UIEvents.Get("OnScreenModeChanged").Event:Connect(function(data)
        isCompactMode = data.IsCompact or false
        SideMenuUI.UpdateLayout(data.Mode)
        
        -- [추가] 미니맵에도 컴팩트 상태 전달 🚩
        if minimapUI and minimapUI.UpdateLayout then
            minimapUI.UpdateLayout(data.Mode, data.IsCompact)
        end
        
        SideMenuUI.UpdateMinimapPosition()
    end)

    -- [동적 메뉴 생성] 🚩 Phase 4 (Hardcoding 제거)
    SideMenuUI.RefreshMenu()
    
    -- 초기 미니맵 위치 연동 🚩
    task.spawn(function()
        task.wait(1)
        SideMenuUI.UpdateMinimapPosition()
    end)

    -- [핵심 수정] 퀵 액세스 아이콘을 패널 내부가 아닌 screenGui(형제)에 직접 생성!
    SideMenuUI.CreateQuickAccess(screenGui)

    Logger.Info("[SideMenuUI] 생성 완료 (반응형 엔진 활성화)")
end

function SideMenuUI.RefreshMenu()
    if not menuContainer then return end
    
    -- 기존 버튼 제거
    for _, child in ipairs(menuContainer:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    menuButtons = {}

    local names = UIEvents.GetRegisteredNames()
    local activeOrder = 1
    
    for _, name in ipairs(names) do
        local module = UIEvents.GetModule(name)
        local config = ServiceConfig[name]
        
        -- 설정이 없거나 Enabled가 true인 경우만 진행
        local isEnabled = (config == true) or (typeof(config) == "table" and config.Enabled == true)
        
        if module and isEnabled then
            -- [신규] 배치 필터링 🚩
            local placement = (typeof(config) == "table" and config.Placement) or "Both"
            local shouldShow = (placement == "Both") 
                or (currentMode == "Mobile" and placement == "Bottom")
                or (currentMode == "PC" and placement == "Right")

            if shouldShow then
                -- 모듈 내 Info가 있으면 사용, 없으면 기본값 🚩
                local info = (module :: any).Info or { id = name, icon = "📦", name = name }
                SideMenuUI.CreateMenuBtn(info, activeOrder)
                activeOrder += 1
            end
        end
    end
end

function SideMenuUI.ToggleMenu()
    if not (sidePanelFrame and menuContainer) then return end
    isMenuExpanded = not isMenuExpanded
    
    local targetSize = (currentMode == "Mobile") and MOBILE_PANEL_SIZE or PC_PANEL_SIZE
    local closedSize = (currentMode == "Mobile") 
        and UDim2.new(MOBILE_PANEL_SIZE.X.Scale, MOBILE_PANEL_SIZE.X.Offset, 0, 48) 
        or UDim2.new(PC_PANEL_SIZE.X.Scale, PC_PANEL_SIZE.X.Offset, 0, 48)

    if isMenuExpanded then
        menuContainer.Visible = true
        if menuExpandIcon then menuExpandIcon.Text = "▲" end
        TweenService:Create(sidePanelFrame, UITheme.Tween.Smooth, {
            Size = targetSize
        }):Play()
    else
        if menuExpandIcon then menuExpandIcon.Text = "▼" end
        TweenService:Create(sidePanelFrame, UITheme.Tween.Smooth, {
            Size = closedSize
        }):Play()
        
        task.delay(0.3, function()
            if not isMenuExpanded and menuContainer then 
                menuContainer.Visible = false 
            end
        end)
    end
end

function SideMenuUI.UpdateLayout(mode: string)
    if not (sidePanelFrame and menuContainer) then return end -- nil 체크 강화 🚩
    currentMode = mode
    
    local grid = menuContainer:FindFirstChildOfClass("UIGridLayout")
    if grid then
        grid.FillDirection = Enum.FillDirection.Horizontal
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        
        if mode == "Mobile" then
            grid.CellSize = UDim2.new(0, 50, 0, 50)
            grid.FillDirectionMaxCells = 0 -- 모바일은 가로로 쭉 (필요시 스크롤)
        else
            grid.CellSize = UDim2.new(0, 46, 0, 58) 
            grid.FillDirectionMaxCells = 3 -- [수정] PC는 1줄에 3개씩 강제 🚩
        end
    end

    SideMenuUI.RefreshMenu()

    if mode == "Mobile" then
        sidePanelFrame.Size = MOBILE_PANEL_SIZE
        sidePanelFrame.Position = MOBILE_PANEL_POS
        sidePanelFrame.AnchorPoint = Vector2.new(1, 1) -- 우측 하단 고정 🚩
    else
        -- [PC 반응형]
        local panelWidth = (isMenuExpanded) and 165 or 60
        local panelHeightScale = isCompactMode and 0.45 or 0.65 -- 높이가 낮으면 짧게 🚩
        sidePanelFrame.Size = UDim2.new(0, panelWidth, panelHeightScale, 0)
        sidePanelFrame.AnchorPoint = Vector2.new(1, 0)
        -- 위치는 UpdateMinimapPosition에서 계산
    end
    
    -- 헤더 높축 대응 🚩
    local header = sidePanelFrame:FindFirstChild("Header") :: TextButton
    if header then
        header.Size = UDim2.new(1, 0, 0, (isCompactMode or mode == "Mobile") and 36 or 48)
    end
end

-- [신규] 미니맵 하단 위치에 맞춰 사이드 메뉴 자동 배치 🚩
function SideMenuUI.UpdateMinimapPosition()
    if not (sidePanelFrame and currentMode ~= "Mobile") then return end
    
    if not minimapUI then
        minimapUI = Framework.GetService("MinimapUI")
    end
    
    if minimapUI and minimapUI.GetBottom then
        local bottomY = minimapUI.GetBottom()
        if bottomY > 0 then
            sidePanelFrame.Position = UDim2.new(1, -15, 0, bottomY + 15) -- 15px 여백 🚩
        end
    end
end

function SideMenuUI.CreateMenuBtn(menu: {id: string, icon: string, name: string}, order: number)
    if not menuContainer then return end
    
    local btn = Instance.new("TextButton")
    btn.Name = "MenuBtn_" .. menu.id
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.LayoutOrder = order
    btn.BackgroundColor3 = UITheme.Colors.Secondary
    btn.BackgroundTransparency = 0.4 -- [수정] 박스 가시성 확보 🚩
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = menuContainer

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = UITheme.Colors.Accent
    btnStroke.Thickness = 1.2
    btnStroke.Transparency = 0.6
    btnStroke.Parent = btn

    -- [통합 스케일링용 UIScale] 🚩
    local uiScale = Instance.new("UIScale")
    uiScale.Parent = btn

    local vLayout = Instance.new("UIListLayout")
    vLayout.FillDirection = Enum.FillDirection.Vertical
    vLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    vLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    vLayout.Padding = UDim.new(0, 0) -- [수정] 간격 최대 밀착 🚩
    vLayout.Parent = btn

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(0, 24, 0, 24) -- [수정] 크기 최적화 🚩
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = menu.icon
    iconLbl.TextColor3 = UITheme.Colors.Accent
    iconLbl.Font = UITheme.Font.Title
    iconLbl.TextSize = 18 -- 좀 더 작게 조절
    iconLbl.Parent = btn

    local textLbl = Instance.new("TextLabel")
    textLbl.Name = "TextLabel" -- 이름 부여 🚩
    textLbl.Size = UDim2.new(1, 0, 0, 16) -- [수정] 높이 축소 🚩
    textLbl.BackgroundTransparency = 1
    textLbl.Text = menu.name
    textLbl.TextColor3 = UITheme.Colors.Text
    textLbl.Font = UITheme.Font.Main
    textLbl.TextSize = 10 -- 텍스트 크기 최적화
    textLbl.TextXAlignment = Enum.TextXAlignment.Center
    textLbl.Parent = btn

    -- [반응형] 아이콘 모드 시 텍스트 자동 숨김 로직 🚩
    local function updateView()
        local isSmall = (currentMode == "PC" and not isMenuExpanded)
        textLbl.Visible = not isSmall
        iconLbl.TextSize = isSmall and 24 or 18
    end
    updateView()

    btn.MouseButton1Click:Connect(function()
        print("[SideMenuUI] 메뉴 버튼 클릭됨 (신호 발송): " .. menu.id)
        UIEvents.Get("ToggleUI"):Fire(menu.id)
    end)

    btn.MouseEnter:Connect(function()
        TweenService:Create(uiScale, UITheme.Tween.Fast, { Scale = 1.15 }):Play() -- 전체 크기 확대 🚩
        TweenService:Create(btnStroke, UITheme.Tween.Fast, { Transparency = 0.2 }):Play()
        TweenService:Create(btn, UITheme.Tween.Fast, { BackgroundTransparency = 0.2 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        local isCurrent = (currentOpenPopup == menu.id)
        TweenService:Create(uiScale, UITheme.Tween.Fast, { Scale = 1.0 }):Play()
        TweenService:Create(btnStroke, UITheme.Tween.Fast, { Transparency = isCurrent and 0.2 or 0.6 }):Play()
        TweenService:Create(btn, UITheme.Tween.Fast, { BackgroundTransparency = isCurrent and 0.2 or 0.4 }):Play()
    end)

    menuButtons[menu.id] = btn
end

function SideMenuUI.TogglePopup(popupName: string)
    print("[SideMenuUI] TogglePopup 실행: " .. popupName)
    if currentOpenPopup == popupName then
        SideMenuUI.ClosePopup(popupName)
        currentOpenPopup = nil
    else
        if currentOpenPopup then
            SideMenuUI.ClosePopup(currentOpenPopup)
        end
        SideMenuUI.OpenPopup(popupName)
        currentOpenPopup = popupName
    end
end

function SideMenuUI.OpenPopup(popupName: string)
    -- [Registry] 모듈 조회 🚩
    local module = UIEvents.GetModule(popupName)
    
    if not module then 
        Logger.Warn("[SideMenuUI] Registry에 등록되지 않은 UI 호출: " .. popupName)
        -- Registry에 없어도 에셋이라도 찾아보려고 시도 (최후의 수단)
        local screenGuiName = popupName
        if popupName == "SettingsUI" then screenGuiName = "Settings" end -- 이름 차이 가능성
        local fallback = pgui:FindFirstChild(screenGuiName .. "Gui") or pgui:FindFirstChild(screenGuiName)
        if fallback and fallback:IsA("ScreenGui") then
            fallback.Enabled = true
            return
        end
        return 
    end

    -- [비주얼 설정] 기존 SideMenuUI의 배치를 유지하려면 프레임 참조가 필요함
    -- 하지만 PopupLayout을 쓰는 프리미엄 UI들은 스스로 중앙 배치를 수행하므로 
    -- 굳이 여기서 위치를 강제로 잡을 필요가 없음 (충돌 원인 제거) 🚩
    
    if module.Open then
        module.Open()
    end

    local btn = menuButtons[popupName]
    if btn then
        local stroke = btn:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Transparency = 0.2 end -- 활성화 시 테두리 강조 🚩
        btn.BackgroundTransparency = 0.2
    end
end

function SideMenuUI.ClosePopup(popupName: string)
    if popupName == "ALL" then
        for _, btn in pairs(menuButtons) do
            local stroke = btn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Transparency = 0.6 end
            btn.BackgroundTransparency = 0.4
        end
        currentOpenPopup = nil
        return
    end

    local btn = menuButtons[popupName]
    if btn then
        local stroke = btn:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Transparency = 0.6 end
        btn.BackgroundTransparency = 0.4
    end
    
    -- [Registry] 모듈 조회 및 닫기 🚩
    local module = UIEvents.GetModule(popupName)
    if module and module.Close then
        module.Close()
    end
end

function SideMenuUI.SetPopupStatus(popupName: string, isOpen: boolean)
    if isOpen then
        if currentOpenPopup and currentOpenPopup ~= popupName then
            SideMenuUI.ClosePopup(currentOpenPopup)
        end
        currentOpenPopup = popupName
        
        -- 활성 상태 시각적 피드백 (테두리 강조) 🚩
        local btn = menuButtons[popupName]
        if btn then
            local stroke = btn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Transparency = 0.2 end
            btn.BackgroundTransparency = 0.2
        end
    else
        if currentOpenPopup == popupName then
            currentOpenPopup = nil
            local btn = menuButtons[popupName]
            if btn then
                local stroke = btn:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Transparency = 0.6 end
                btn.BackgroundTransparency = 0.4
            end
        end
    end
end

-- [핵심 수정] 부모를 panel이 아닌 screenGui로 받도록 수정
function SideMenuUI.CreateQuickAccess(parent: ScreenGui)
    local quickContainer = Instance.new("Frame")
    quickContainer.Name = "QuickAccess"
    quickContainer.Size = UDim2.new(0, 120, 0, 60)
    
    -- [하단 중앙 배치] 채팅창 하단 높이(-30)에 맞춤
    quickContainer.Position = UDim2.new(0.5, 0, 1, -30)
    quickContainer.AnchorPoint = Vector2.new(0.5, 1)
    
    quickContainer.BackgroundTransparency = 1
    quickContainer.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 12)
    layout.FillDirection = Enum.FillDirection.Horizontal -- 가로 배치
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = quickContainer

    local function createIconBtn(id: string, icon: string)
        local btn = Instance.new("TextButton")
        btn.Name = "QuickBtn_" .. id
        btn.Size = UDim2.new(0, 44, 0, 44)
        btn.BackgroundColor3 = UITheme.Colors.Secondary
        btn.BackgroundTransparency = 0.2
        btn.Text = icon
        btn.TextColor3 = UITheme.Colors.Text
        btn.TextSize = 22
        btn.Font = UITheme.Font.Bold
        btn.Parent = quickContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = UITheme.Colors.Accent
        stroke.Thickness = 1.5
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = btn

        btn.MouseButton1Click:Connect(function()
            UIEvents.Get("ToggleUI"):Fire(id)
        end)

        -- 호버 연출
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, UITheme.Tween.Fast, {
                BackgroundColor3 = UITheme.Colors.Accent,
                Size = UDim2.new(0, 46, 0, 46)
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            local isCurrent = (currentOpenPopup == id)
            TweenService:Create(btn, UITheme.Tween.Fast, {
                BackgroundColor3 = isCurrent and UITheme.Colors.Accent or UITheme.Colors.Secondary,
                Size = UDim2.new(0, 44, 0, 44)
            }):Play()
        end)

        menuButtons[id] = btn
    end

    local function updateResponsive(data: {Mode: string, IsCompact: boolean?}?)
        local mode = if data then data.Mode else ResponsiveManager.GetMode()
        local isCompact = if data then data.IsCompact else isCompactMode
        
        local iconSize = (mode == "Mobile" or isCompact) and 36 or 44 
        local containerHeight = (mode == "Mobile" or isCompact) and 50 or 60
        
        quickContainer.Size = UDim2.new(0, 120, 0, containerHeight)
        -- 높이가 낮으면 더 바닥에 밀착 🚩
        quickContainer.Position = UDim2.new(0.5, 0, 1, isCompact and -10 or -30)
        
        for _, btn in pairs(menuButtons) do
            if btn.Name:find("QuickBtn_") then
                btn.Size = UDim2.new(0, iconSize, 0, iconSize)
                local stroke = btn:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Thickness = (mode == "Mobile") and 1 or 1.5 end
            end
        end
    end

    -- 초기화 및 구독 🚩
    updateResponsive()
    UIEvents.Get("OnScreenModeChanged").Event:Connect(updateResponsive)

    createIconBtn("SkillUI", "✨")
    createIconBtn("InventoryUI", "🎒")
end

return SideMenuUI