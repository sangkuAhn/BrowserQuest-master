--!strict
--[[
    [UITheme.luau]
    NewQuest의 모든 UI가 공유하는 디자인 토큰(Single Source of Truth)입니다.
    색상, 스타일, 트윈, 사운드를 여기서 한 번에 관리합니다.
]]

local UITheme = {}

-- [0. 전역 제어 스위치] 🚩
UITheme.EnableAnimation = true -- UI 트윈 애니메이션 사용 여부
UITheme.CurrentMotion = "SlideUp" -- 기본 모션 (Classic, SlideUp, Zoom, Elastic) 🚩
UITheme.AnimSpeedMultiplier = 1.0  -- [신규] 애니메이션 속도 배율 (0.5x, 1.0x, 2.0x 등) 🚩

-- 1. [명품 색상 팔레트]
UITheme.Colors = {
    Main = Color3.fromRGB(25, 25, 35),      -- 깊은 밤의 네이비 (배경)
    Secondary = Color3.fromRGB(40, 40, 55), -- 조금 더 밝은 네이비 (패널/카드)
    Header = Color3.fromRGB(35, 35, 50),    -- 헤더 영역
    
    Accent = Color3.fromRGB(100, 150, 255),  -- 시그니처 블루
    Gold = Color3.fromRGB(255, 200, 100),    -- 프리미엄 포인트 (어드민 등)
    
    Text = Color3.fromRGB(240, 240, 240),    -- 메인 텍스트 (화이트에 가까운 회색)
    TextSub = Color3.fromRGB(180, 180, 190), -- 보조 텍스트
    
    Success = Color3.fromRGB(80, 220, 120),
    Error = Color3.fromRGB(255, 80, 80),
    
    ModalOverlay = Color3.fromRGB(0, 0, 0),  -- 배경 어둡기
    ModalTransparency = 0.5
}

-- 2. [가이드 및 형태 토큰]
UITheme.Shapes = {
    CornerRadius = UDim.new(0, 12),
    StrokeThickness = 2,
    HeaderHeight = UDim2.new(1, 0, 0, 50),
    StandardPopupSize = UDim2.new(0.4, 0, 0.65, 0), -- [수정] 고정 픽셀에서 비율 소스로 전환 🚩
    
    -- [반응형 제약 조건] 🚩
    MinSize = Vector2.new(300, 400),     -- 모바일 최소 보장 크기
    MaxSize = Vector2.new(800, 900),     -- PC 최대 제한 크기
    AspectRatio = 0.8,                    -- 황금비 (가로/세로)
    TouchBtnSize = 44                     -- 터치 최적화 버튼 최소 크기 (px)
}

-- 2.5 [폰트 토큰] 🚩
UITheme.Font = {
    Main = Enum.Font.GothamMedium,
    Title = Enum.Font.LuckiestGuy,
    Bold = Enum.Font.GothamBold
}

-- 3. [모션 토큰 (PM의 비법 소스)] 🚩
UITheme.Tween = {
    -- [최적화] 가볍고 즉각적인 반응을 위해 연출 단순화🚩
    Smooth = TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    Fast = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Quick = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    Linear = TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
}

-- [모션 전역 시간 설정] 🚩PopupLayout에서 AnimSpeedMultiplier와 조합됨
UITheme.MotionDurations = {
    Classic = 0.15,
    SlideUp = 0.2,
    SlideDown = 0.2,
    SlideLeft = 0.2,
    SlideRight = 0.2,
    ZoomIn = 0.15,
    ZoomOut = 0.2,
    Elastic = 0.4,
    Spiral = 0.35,
    Tilt = 0.25,
    ExpandV = 0.2,
    ExpandH = 0.2
}

-- 4. [사운드 토큰 (PM의 비법 소스)] 🚩
UITheme.Sounds = {
    Click = "rbxassetid://6895079853",
    Hover = "rbxassetid://6042048331", -- 유효한 호버 사운드로 교체🚩
    Open = "rbxassetid://9114221327",
    Close = "rbxassetid://9114221327" -- 임시 (동일 사운드)
}

return UITheme
