--!strict
--[[
    [PopupLayout.luau]
    PM의 '비법 소스'가 반영된 프리미엄 팝업 레이아웃 엔진입니다.
    CanvasGroup, Blur, Esc/ClickOutside 닫기 로직을 내장합니다.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(Shared:WaitForChild("Data"):WaitForChild("UITheme"))
local Logger = require(Shared:WaitForChild("Core"):WaitForChild("Logger")) -- [추가] 🚩

local PopupLayout = {}

-- [타입 정의] 🚩
export type PopupElements = {
    ScreenGui: ScreenGui,
    MainFrame: CanvasGroup,
    ContentFrame: any, -- [수정] 린트 충돌 방지 위해 any로 변경 🚩
    Footer: Frame?,
    Open: () -> (),
    Close: () -> ()
}

-- 전역 레이어 관리 테이블 🚩
local openPopups = {}
local activeGuis: { [string]: ScreenGui } = {} -- [수정] 타입 힌트 명시 🚩
local TOP_DISPLAY_ORDER = 200

-- [신규] 레이어 포커스 시스템 🚩
function PopupLayout.Focus(screenGui: ScreenGui)
    for _, gui in pairs(activeGuis) do
        if (gui :: any) == (screenGui :: any) then
            gui.DisplayOrder = TOP_DISPLAY_ORDER
        else
            -- 다른 가이들은 기본 오더로 내림
            if gui.DisplayOrder >= TOP_DISPLAY_ORDER then
                gui.DisplayOrder = 150
            end
        end
    end
end

-- [1. 버튼 팩토리] 🚩 사운드와 애니메이션 자동 장착
function PopupLayout.CreateButton(name: string, text: string, parent: Instance): TextButton
    local btn = Instance.new("TextButton")
    btn.Name = name .. "_Btn"
    btn.Size = UDim2.new(1, -20, 0, 45)
    btn.BackgroundColor3 = UITheme.Colors.Secondary
    btn.AutoButtonColor = false
    btn.Text = text
    btn.TextColor3 = UITheme.Colors.Text
    btn.TextSize = 18
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = parent

    -- [가독성 방어선] 🚩
    local textSizeConstraint = Instance.new("UITextSizeConstraint", btn)
    textSizeConstraint.MinTextSize = 12

    Instance.new("UICorner", btn).CornerRadius = UITheme.Shapes.CornerRadius
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = UITheme.Colors.Accent
    stroke.Transparency = 0.5
    stroke.Thickness = 1
    stroke.Parent = btn

    -- 호버 연출
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, UITheme.Tween.Fast, {
            BackgroundColor3 = UITheme.Colors.Accent,
            Size = UDim2.new(1, -10, 0, 48)
        }):Play()
        
        -- 사운드 재생 추가 🚩
        local s = Instance.new("Sound")
        s.SoundId = UITheme.Sounds.Hover
        s.Volume = 0.3
        s.Parent = ReplicatedStorage
        s:Play()
        s.Ended:Connect(function() s:Destroy() end)
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, UITheme.Tween.Fast, {
            BackgroundColor3 = UITheme.Colors.Secondary,
            Size = UDim2.new(1, -20, 0, 45)
        }):Play()
    end)

    -- 클릭 사운드 및 피드백 🚩
    btn.MouseButton1Click:Connect(function()
        local s = Instance.new("Sound")
        s.SoundId = UITheme.Sounds.Click
        s.Volume = 0.5
        s.Parent = ReplicatedStorage
        s:Play()
        s.Ended:Connect(function() s:Destroy() end)
    end)

    btn.MouseButton1Down:Connect(function()
        btn:TweenSize(UDim2.new(0.95, -20, 0, 42), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
    end)

    return btn
end

-- [2. 표준 프리미엄 팝업 생성] 🚩 다형성 레이아웃 및 제약 조건 주입
function PopupLayout.CreateStandardPopup(id: string, title: string, customPosition: UDim2?, layoutType: string?)
    local player = Players.LocalPlayer
    local pgui = player:WaitForChild("PlayerGui")
    layoutType = layoutType or "Centered" -- 기본값
    
    -- 기존 동일 ID 제거
    local old = pgui:FindFirstChild(id .. "_Gui")
    if old then old:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = id .. "_Gui"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 150
    screenGui.Enabled = false
    screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets -- [추가] Safe Area 대응 🚩
    screenGui.Parent = pgui
    
    activeGuis[id] = screenGui -- 레지스트리 등록 🚩
    
    -- 모달 배경 (Click Outside to Close)
    local modalBg = Instance.new("TextButton")
    modalBg.Name = "ModalOverlay"
    modalBg.Size = UDim2.new(1, 0, 1, 0)
    modalBg.BackgroundColor3 = UITheme.Colors.ModalOverlay
    modalBg.BackgroundTransparency = 1
    modalBg.Text = ""
    modalBg.AutoButtonColor = false
    modalBg.Parent = screenGui
    
    -- 배경 블러 (Glassmorphism) 🚩
    local blur = Instance.new("BlurEffect")
    blur.Name = id .. "_Blur"
    blur.Size = 0
    blur.Parent = game.Lighting

    -- 본체 (CanvasGroup으로 최적화) 🚩
    local mainFrame = Instance.new("CanvasGroup")
    mainFrame.Name = "MainFrame"
    
    -- [레이아웃 분기 처리] 🚩 PM 지시 사항 반영
    if layoutType == "FullSheet" then
        -- 모바일 최적화: 하단 풀 시트
        mainFrame.Size = UDim2.new(1, 0, 0.85, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 1, 0)
        mainFrame.AnchorPoint = Vector2.new(0.5, 1)
    elseif layoutType == "SplitView" then
        -- PC 최적화: 좌/우 분활 (기존 customPosition 활용)
        mainFrame.Size = UITheme.Shapes.StandardPopupSize
        mainFrame.Position = customPosition or UDim2.new(0.2, 0, 0.5, 0)
        mainFrame.AnchorPoint = Vector2.new(0, 0.5)
    else
        -- 기본 (Centered)
        mainFrame.Size = UITheme.Shapes.StandardPopupSize
        mainFrame.Position = customPosition or UDim2.new(0.5, 0, 0.5, 0)
        mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    end
    
    mainFrame.BackgroundColor3 = UITheme.Colors.Main
    mainFrame.GroupTransparency = 1
    mainFrame.Parent = screenGui
    
    -- [반응형 제약 조건 자동 주입] 🚩
    local sizeConstraint = Instance.new("UISizeConstraint", mainFrame)
    sizeConstraint.MinSize = UITheme.Shapes.MinSize
    sizeConstraint.MaxSize = UITheme.Shapes.MaxSize

    local aspectConstraint = Instance.new("UIAspectRatioConstraint", mainFrame)
    aspectConstraint.AspectRatio = UITheme.Shapes.AspectRatio
    aspectConstraint.AspectType = Enum.AspectType.ScaleWithParentSize
    aspectConstraint.DominantAxis = Enum.DominantAxis.Height
    
    -- 포커스 이벤트 연결
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            PopupLayout.Focus(screenGui)
        end
    end)
    
    Instance.new("UICorner", mainFrame).CornerRadius = UITheme.Shapes.CornerRadius
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = UITheme.Shapes.StrokeThickness
    stroke.Color = UITheme.Colors.Secondary
    stroke.Parent = mainFrame
    
    -- [Header] 제목 및 닫기 버튼
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UITheme.Shapes.HeaderHeight
    header.BackgroundColor3 = UITheme.Colors.Header
    header.Parent = mainFrame
    Instance.new("UICorner", header).CornerRadius = UITheme.Shapes.CornerRadius
    
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -60, 1, 0)
    titleLbl.Position = UDim2.new(0, 20, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = UITheme.Colors.Text
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 20
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = header

    -- [가독성 방어선] 🚩
    local textSizeConstraint = Instance.new("UITextSizeConstraint", titleLbl)
    textSizeConstraint.MinTextSize = 14 -- 최소 14px 보장
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0.5, 0)
    closeBtn.AnchorPoint = Vector2.new(0, 0.5)
    closeBtn.BackgroundColor3 = UITheme.Colors.Error
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)

    -- [드래그 기능 지원] 🚩
    local dragging = false
    local dragInput: InputObject? = nil
    local dragStart = Vector3.new()
    local startPos = UDim2.new()

    header.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input: InputObject)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- [사운드 재생 유틸리티] 🚩
    local function _playSound(soundId: string)
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = 0.5
        sound.Parent = ReplicatedStorage
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)
    end

    -- [Body] 스크롤 영역
    local body = Instance.new("ScrollingFrame")
    body.Name = "Body"
    body.Size = UDim2.new(1, -20, 1, -110)
    body.Position = UDim2.new(0, 10, 0, 60)
    body.BackgroundTransparency = 1
    body.ScrollBarThickness = 3
    body.ScrollBarImageColor3 = UITheme.Colors.Accent
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.CanvasSize = UDim2.new(0, 0, 0, 0)
    body.Parent = mainFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = body

    -- [Footer] 하단 영역
    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.Size = UDim2.new(1, 0, 0, 50)
    footer.Position = UDim2.new(0, 0, 1, -50)
    footer.BackgroundTransparency = 1
    footer.Parent = mainFrame

    local onClosed = Instance.new("BindableEvent") -- [신규] 🚩

    -- [닫기 로직] 🚩 
    -- [!CRITICAL POLICY] 닫기 애니메이션은 절대 사용하지 않습니다. (No Motion, No Animation)
    -- 사용자 정책에 따라 닫기 버튼 클릭 시 어떠한 트윈이나 지연 없이 즉각적으로 종료되어야 합니다.
    local function close()
        -- 1. 즉각 비활성화 🚩
        screenGui.Enabled = false
        
        -- 2. 상태 초기화 (재사용 대비)
        mainFrame.GroupTransparency = 1
        modalBg.BackgroundTransparency = 1
        
        -- 3. 리소스 정리
        if blur.Parent then 
            blur:Destroy() 
        end
        
        -- 4. 관리 레지스트리 제거
        openPopups[id] = nil
        
        onClosed:Fire() -- [신규] 종료 이벤트 발송 🚩
        Logger.Debug(string.format("[PopupLayout] 팝업 즉각 종료: %s", id))
    end

    -- [참고] 일괄 종료가 필요한 경우 외부에서 PopupLayout.CloseAll() 직접 호출 가능
    function PopupLayout.CloseAll()
        Logger.Info("[PopupLayout] 모든 팝업 일괄 종료 실행")
        -- 레지스트리 복사본으로 순회하여 런타임 수정 오작동 방지
        local toClose = {}
        for popupId, closeFunc in pairs(openPopups) do
            toClose[popupId] = closeFunc
        end

        for _, closeFunc in pairs(toClose) do
            if typeof(closeFunc) == "function" then
                closeFunc()
            end
        end
    end

    closeBtn.MouseButton1Click:Connect(close)
    modalBg.MouseButton1Click:Connect(close)

    -- ESC 키 바인딩 🚩
    openPopups[id] = close

    -- [오픈 애니메이션] 🚩
    local function open()
        screenGui.Enabled = true
        
        local targetPos = mainFrame.Position -- [수정] 현재 설정된 좌표를 타겟으로 고정 🚩
        local targetSize = UITheme.Shapes.StandardPopupSize

        if not UITheme.EnableAnimation then
            mainFrame.GroupTransparency = 0
            mainFrame.Size = targetSize
            modalBg.BackgroundTransparency = UITheme.Colors.ModalTransparency
            blur.Size = 15
            return
        end

        local motion = UITheme.CurrentMotion or "Classic"
        local speed = UITheme.AnimSpeedMultiplier or 1.0
        local baseDuration = UITheme.MotionDurations[motion] or 0.15
        local duration = baseDuration * speed

        blur.Size = 12 
        
        -- 초기 상태 초기화
        mainFrame.Rotation = 0
        -- mainFrame.Position = targetPos -- 초기 위치 고정 🚩

        if motion == "Classic" then
            mainFrame.GroupTransparency = 1
            mainFrame.Size = UDim2.new(0.95 * targetSize.X.Scale, 0.95 * targetSize.X.Offset, 0.95 * targetSize.Y.Scale, 0.95 * targetSize.Y.Offset)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Size = targetSize }):Play()
        
        elseif motion == "SlideUp" then
            mainFrame.GroupTransparency = 1
            mainFrame.Size = targetSize
            mainFrame.Position = targetPos + UDim2.new(0, 0, 0.1, 0)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Position = targetPos }):Play()
            
        elseif motion == "SlideDown" then
            mainFrame.GroupTransparency = 1
            mainFrame.Size = targetSize
            mainFrame.Position = targetPos + UDim2.new(0, 0, -0.1, 0)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Position = targetPos }):Play()
        elseif motion == "SlideLeft" then
            mainFrame.GroupTransparency = 1
            mainFrame.Size = targetSize
            mainFrame.Position = targetPos + UDim2.new(0.1, 0, 0, 0)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Position = targetPos }):Play()
        elseif motion == "SlideRight" then
            mainFrame.GroupTransparency = 1
            mainFrame.Size = targetSize
            mainFrame.Position = targetPos + UDim2.new(-0.1, 0, 0, 0)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Position = targetPos }):Play()
        elseif motion == "ZoomIn" then
            mainFrame.GroupTransparency = 1
            mainFrame.Position = targetPos
            mainFrame.Size = UDim2.new(0.1, 0, 0.1, 0)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Size = targetSize }):Play()
        elseif motion == "ZoomOut" then
            mainFrame.GroupTransparency = 1
            mainFrame.Position = targetPos
            mainFrame.Size = UDim2.new(1.5, 0, 1.5, 0)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Size = targetSize }):Play()
        elseif motion == "Elastic" then
            mainFrame.GroupTransparency = 1
            mainFrame.Position = targetPos
            mainFrame.Size = UDim2.new(0.7, 0, 0.7, 0)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { GroupTransparency = 0, Size = targetSize }):Play()
        elseif motion == "Spiral" then
            mainFrame.GroupTransparency = 1
            mainFrame.Position = targetPos
            mainFrame.Size = UDim2.new(0, 0, 0, 0)
            mainFrame.Rotation = -180
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Size = targetSize, Rotation = 0 }):Play()
        elseif motion == "Tilt" then
            mainFrame.GroupTransparency = 1
            mainFrame.Position = targetPos
            mainFrame.Size = targetSize
            mainFrame.Rotation = 15
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { GroupTransparency = 0, Rotation = 0 }):Play()
        elseif motion == "ExpandV" then
            mainFrame.GroupTransparency = 1
            mainFrame.Position = targetPos
            mainFrame.Size = UDim2.new(targetSize.X.Scale, targetSize.X.Offset, 0, 0)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Size = targetSize }):Play()
        elseif motion == "ExpandH" then
            mainFrame.GroupTransparency = 1
            mainFrame.Position = targetPos
            mainFrame.Size = UDim2.new(0, 0, targetSize.Y.Scale, targetSize.Y.Offset)
            TweenService:Create(mainFrame, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Size = targetSize }):Play()
        end

        TweenService:Create(modalBg, UITheme.Tween.Fast, { BackgroundTransparency = UITheme.Colors.ModalTransparency }):Play()
    end

    return {
        ScreenGui = screenGui,
        MainFrame = mainFrame,
        ContentFrame = body,
        Footer = footer,
        Open = open,
        Close = close,
        OnClosed = onClosed.Event -- [신규] 🚩
    }
end

-- [3. 하위 호환성 래퍼: CreateLayout1] 🚩
-- 기존 UI들이 에러 없이 작동하도록 브릿지 역할을 수행합니다.
function PopupLayout.CreateLayout1(config: any): PopupElements
    local popup = PopupLayout.CreateStandardPopup(config.Name, config.Title or "WINDOW", config.Position)
    
    return popup -- 이제 필드명이 동일하므로 직접 리턴 가능 🚩
end

-- ESC 키 전역 감시
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape then
        -- [복구] 최상단 팝업 하나만 닫음 🚩
        for id, closeFunc in pairs(openPopups) do
            closeFunc()
            break 
        end
    end
end)

return PopupLayout
