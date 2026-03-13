--!strict
--[[
    [HUDService/init.luau]
    메인 HUD의 수명 주기와 서버 통신을 중계하는 Mediator 모듈입니다.
    세부 UI 로직은 BossBarUI, SkillBarUI, StatusBarUI, SideMenuUI로 분산되어 있습니다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("Logger"))
local UIEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("UIEvents"))

-- 서브 모듈 로드 (고정 UI)
local BossBarUI = require(script:WaitForChild("BossBarUI"))
local SkillBarUI = require(script:WaitForChild("SkillBarUI"))
local StatusBarUI = require(script:WaitForChild("StatusBarUI"))
local SideMenuUI = require(script:WaitForChild("SideMenuUI"))
local TopLeftUI = require(script:WaitForChild("TopLeftUI"))

local HUDService = {
    Name = "HUDService"
}

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local mainHUD: ScreenGui?

local currentOpenPopup: string? = nil

-- ─────────────────────────────────────────────────────────────
-- [Mediator] 초기화
-- ─────────────────────────────────────────────────────────────
function HUDService:Init()
    Logger.Info("[HUDService] 관제탑(Mediator) 초기화 중...")
    
    -- [중요] 모든 UI 토글 신호 집중 관리 🚩
    local isProcessingToggle = false
    UIEvents.Get("ToggleUI").Event:Connect(function(uiName: string)
        if isProcessingToggle then return end
        isProcessingToggle = true
        
        Logger.Info("[HUDService] UI 토글 요청 수신: " .. uiName)
        
        -- 1. [Registry] 등록된 모듈 찾기 🚩
        local module = UIEvents.GetModule(uiName)

        if module then
            -- [핵심] 팝업 개폐 상태 판단 및 명시적 제어
            local isOpen = false
            if module.MainFrame then
                isOpen = module.MainFrame.Visible
            elseif module.ScreenGui then
                isOpen = module.ScreenGui.Enabled
            elseif module.IsOpen then -- [추가] 인터페이스 지원
                isOpen = module.IsOpen()
            end

            if isOpen then
                if module.Close then module.Close() end
                SideMenuUI.SetPopupStatus(uiName, false)
            else
                HUDService.CloseAllPopupsExcept(uiName)
                if module.Open then module.Open() end -- PM 지시사항 반영 (Open 호출) 🚩
                SideMenuUI.SetPopupStatus(uiName, true)
            end
        else
            -- 폴백: SideMenuUI 기존 시스템
            SideMenuUI.TogglePopup(uiName)
        end
        
        task.wait() -- 동일 프레임 내 중복 신호 방지
        isProcessingToggle = false
    end)

    -- MainHUD ScreenGui 확보 (또는 생성)
    mainHUD = pgui:FindFirstChild("MainHUD") or Instance.new("ScreenGui")
    if mainHUD then
        mainHUD.Name = "MainHUD"
        mainHUD.IgnoreGuiInset = true
        mainHUD.ResetOnSpawn = false
        mainHUD.Parent = pgui
    end
    
    -- 서브 모듈 초기화 및 생성
    Logger.Info("[HUDService] 서브 모듈 생성 시작...")
    StatusBarUI.Create(mainHUD :: ScreenGui)
    BossBarUI.Create(mainHUD :: ScreenGui)
    SkillBarUI.Create(mainHUD :: ScreenGui)
    SideMenuUI.Create(mainHUD :: ScreenGui)
    TopLeftUI.Create(mainHUD :: ScreenGui)
    
    Logger.Info("[HUDService] 모든 서브 모듈 생성 성공")

    -- 단축키 바인딩
    ContextActionService:BindAction("ToggleStatsUI_Hotkey", function(actionName, inputState, inputObj)
        if inputState == Enum.UserInputState.Begin then
            SideMenuUI.TogglePopup("StatusUIService")
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.T)

    player.CharacterAdded:Connect(function(char)
        HUDService:BindCharacter(char)
    end)
    if player.Character then
        HUDService:BindCharacter(player.Character)
    end
end

-- [신규] 모든 팝업 닫기 유틸리티 (Registry 연동) 🚩
function HUDService.CloseAllPopupsExcept(exceptionName: string?)
    for _, moduleName in pairs(UIEvents.GetRegisteredNames()) do
        if moduleName == exceptionName then continue end
        
        local module = UIEvents.GetModule(moduleName)
        if module and module.Close then
            module.Close()
        end
    end
    SideMenuUI.ClosePopup("ALL")
end

-- ─────────────────────────────────────────────────────────────
-- [Mediator] 캐릭터 관련 이벤트 바인딩
-- ─────────────────────────────────────────────────────────────
function HUDService:BindCharacter(char: Model)
    local hum = char:WaitForChild("Humanoid") :: Humanoid
    hum.HealthChanged:Connect(function(health)
        StatusBarUI.UpdateBars(health, hum.MaxHealth)
    end)
    StatusBarUI.UpdateBars(hum.Health, hum.MaxHealth)
end

-- ─────────────────────────────────────────────────────────────
-- [Mediator] 서비스 시작
-- ─────────────────────────────────────────────────────────────
function HUDService:Start()
    Logger.Info("[HUDService] Mediator 서비스 시작 중...")
    
    -- 서버 데이터 동기화
    local network = ReplicatedStorage:WaitForChild("Network")
    local syncEvent = network:WaitForChild("SyncPlayerData") :: RemoteEvent
    syncEvent.OnClientEvent:Connect(function(data)
        if not data then return end
        StatusBarUI.UpdateLevel(data.Level or 1)
        if data.Stats then
            StatusBarUI.UpdateMP(data.Stats.CurrentMana or 0, data.Stats.MaxMana or 50)
            StatusBarUI.UpdateStamina(data.Stats.CurrentStamina or 100, data.Stats.MaxStamina or 100)
        end
    end)

    -- 보스 신호 수신
    local bossSignal = network:WaitForChild("BossSignal") :: RemoteEvent
    bossSignal.OnClientEvent:Connect(function(bossName: string, currentHP: number, maxHP: number)
        BossBarUI.Update(bossName, currentHP, maxHP)
    end)
    
    Logger.Info("[HUDService] 가동 완료.")
end

-- ─────────────────────────────────────────────────────────────
-- [공개 API] 다른 모듈에서 호출할 수 있는 인터페이스
-- ─────────────────────────────────────────────────────────────
function HUDService.UpdateBossBar(name: string, current: number, maxHP: number)
    BossBarUI.Update(name, current, maxHP)
end

function HUDService.UpdateSkillIcon(weaponClass: string)
    SkillBarUI.UpdateIcon(weaponClass)
end

function HUDService.PlaySkillCooldown(duration: number)
    SkillBarUI.PlayCooldown(duration)
end

function HUDService.SetPopupStatus(name: string, isOpen: boolean)
    SideMenuUI.SetPopupStatus(name, isOpen)
end

function HUDService.TogglePopup(name: string)
    SideMenuUI.TogglePopup(name)
end

return HUDService