--!strict
--[[
    [ResponsiveManager.luau]
    화면 해상도 변화 및 입력 장치(Touch/Mouse)를 실시간 감지하여
    전역 UI 상태(OnScreenModeChanged)를 관리하는 중앙 제어 매니저입니다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Core"):WaitForChild("Logger"))
local UIEvents = require(Shared:WaitForChild("Core"):WaitForChild("UIEvents"))

local ResponsiveManager = {}
ResponsiveManager.Name = "ResponsiveManager"

-- [상태 변수]
local currentMode = "PC"
local isTouchOptimized = false
local lastInformedSize = Vector2.new(0, 0)
local resizeDebounce = false

-- [상수]
local BREAKPOINT_MOBILE = 768 -- 모바일/태블릿 분기점 (px)
local BREAKPOINT_COMPACT = 500 -- 컴팩트/가로모드 분기점 (px) 🚩
local DEBOUNCE_TIME = 0.15    -- 리사이즈 디바운싱 시간 (초)

-- 레이아웃 상태 업데이트 (내부 로직)
local function updateLayout()
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    local size = camera.ViewportSize
    if size == lastInformedSize then return end
    lastInformedSize = size
    
    -- 1. 화면 모드 결정 (PC vs Mobile)
    local newMode = (size.X < BREAKPOINT_MOBILE) and "Mobile" or "PC"
    
    -- 2. 컴팩트 모드 여부 (높이가 낮을 때) 🚩
    local isCompact = (size.Y < BREAKPOINT_COMPACT)
    
    -- 3. 터치 최적화 여부 결정
    local touchEnabled = UserInputService.TouchEnabled
    
    -- 상태 변화 시 신호 발송
    if currentMode ~= newMode or isTouchOptimized ~= touchEnabled then
        currentMode = newMode
        isTouchOptimized = touchEnabled
        
        Logger.Info(string.format("[Responsive] 모드 변경: %s (Compact: %s, Touch: %s)", newMode, tostring(isCompact), tostring(touchEnabled)))
        
        -- 전역 신호 발송 (UIEvents 기반)
        UIEvents.Get("OnScreenModeChanged"):Fire({
            Mode = newMode,
            IsCompact = isCompact,
            IsTouch = touchEnabled,
            ViewportSize = size
        })
    end
end

-- 디바운싱 처리된 리사이즈 핸들러
local function onResize()
    if resizeDebounce then return end
    resizeDebounce = true
    
    task.delay(DEBOUNCE_TIME, function()
        resizeDebounce = false
        updateLayout()
    end)
end

-- [Framework Lifecycle]
function ResponsiveManager:Init()
    local camera = workspace.CurrentCamera
    
    -- 초기 상태 강제 업데이트
    task.spawn(updateLayout)
    
    -- 화면 크기 변경 감지 (디바운싱 적용)
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(onResize)
    
    -- 입력 장치 변경 감지 (필요 시)
    UserInputService.LastInputTypeChanged:Connect(function()
        updateLayout()
    end)
    
    Logger.Info("[ResponsiveManager] 초기화 완료 (디바운싱 0.15s 적용)")
end

function ResponsiveManager:Start()
    -- 추가적인 런타임 로직이 필요하면 여기에 작성
end

-- [Public API] 현재 상태 조회
function ResponsiveManager.GetMode(): string
    return currentMode
end

function ResponsiveManager.IsTouchOptimized(): boolean
    return isTouchOptimized
end

return ResponsiveManager
