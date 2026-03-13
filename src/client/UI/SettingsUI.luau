--!strict
--[[
    [SettingsUI.luau]
    Legion v2 프리미엄 UI 시스템이 적용된 게임 설정 창입니다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Core"):WaitForChild("Logger"))
local T = require(Shared:WaitForChild("Core"):WaitForChild("LanguageManager"))
local UITheme = require(Shared:WaitForChild("Data"):WaitForChild("UITheme"))
local PopupLayout = require(Shared:WaitForChild("Core"):WaitForChild("PopupLayout"))
local UIEvents = require(Shared:WaitForChild("Core"):WaitForChild("UIEvents"))

local SettingsService = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Core"):WaitForChild("SettingsService"))

local SettingsUI = {}
SettingsUI.Info = { id = "SettingsUI", icon = "⚙️", name = "설정" } -- [추가] 🚩
local popup = nil

-- [볼륨 조절용 프리미엄 컨트롤] 🚩
local function CreateVolumeControl(name: string, labelText: string, settingKey: string, parent: Instance)
    local container = Instance.new("Frame")
    container.Name = name .. "Control"
    container.Size = UDim2.new(0.9, 0, 0, 50)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = UITheme.Colors.TextSub
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local controlFrame = Instance.new("Frame")
    controlFrame.Size = UDim2.new(0.6, 0, 0.7, 0)
    controlFrame.Position = UDim2.new(0.4, 0, 0.15, 0)
    controlFrame.BackgroundTransparency = 1
    controlFrame.Parent = container

    local function createBtn(text: string, pos: UDim2)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 32, 1, 0)
        b.Position = pos
        b.BackgroundColor3 = UITheme.Colors.Secondary
        b.TextColor3 = UITheme.Colors.Text
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 18
        b.Parent = controlFrame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        Instance.new("UIStroke", b).Color = UITheme.Colors.Accent
        return b
    end

    local minusBtn = createBtn("-", UDim2.new(0, 0, 0, 0))
    local plusBtn = createBtn("+", UDim2.new(1, -32, 0, 0))
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(1, -74, 1, 0)
    valueLabel.Position = UDim2.new(0, 37, 0, 0)
    valueLabel.BackgroundColor3 = UITheme.Colors.Main
    valueLabel.TextColor3 = UITheme.Colors.Accent
    valueLabel.Font = Enum.Font.Code
    valueLabel.TextSize = 16
    valueLabel.Parent = controlFrame
    Instance.new("UICorner", valueLabel).CornerRadius = UDim.new(0, 4)

    local function refresh()
        local val = SettingsService.GetSettings()[settingKey] or 0.5
        valueLabel.Text = string.format("%d%%", math.round(val * 100))
    end

    minusBtn.MouseButton1Click:Connect(function()
        local current = SettingsService.GetSettings()[settingKey] or 0.5
        SettingsService:UpdateSetting(settingKey, math.clamp(current - 0.1, 0, 1))
        refresh()
    end)

    plusBtn.MouseButton1Click:Connect(function()
        local current = SettingsService.GetSettings()[settingKey] or 0.5
        SettingsService:UpdateSetting(settingKey, math.clamp(current + 0.1, 0, 1))
        refresh()
    end)

    refresh()
end

function SettingsUI.Create()
    if popup then return end -- [추가] 중복 생성 방지 🚩
    Logger.Info("[SettingsUI] 프리미엄 인터페이스 생성...")
    popup = PopupLayout.CreateStandardPopup("Settings", T.get("UI_Settings_Title") or "GAME SETTINGS")
    
    local body = popup.ContentFrame -- [수정] 🚩
    
    -- 1. 토글 버튼들 (디자인 시스템 적용)
    local function addOpt(id: string, label: string, key: string)
        local btn = PopupLayout.CreateButton(id, label, body)
        local function update()
            local enabled = SettingsService.GetSettings()[key]
            btn.Text = label .. (enabled and " [ON]" or " [OFF]")
            btn.TextColor3 = enabled and UITheme.Colors.Success or UITheme.Colors.TextSub
        end
        btn.MouseButton1Click:Connect(function()
            SettingsService:UpdateSetting(key, not SettingsService.GetSettings()[key])
            update()
        end)
        update()
    end

    addOpt("Shadow", "그림자 효과 (Shadows)", "ShadowsEnabled")
    addOpt("HidePlayers", "다른 유저 숨기기 (Hide Players)", "HideOtherPlayers")
    addOpt("LowDetail", "저사양 모드 (Low Detail)", "LowDetailMode")
    addOpt("ColorBlind", "색상 보정 (Color Blind)", "ColorBlindMode")

    -- 2. 볼륨 조절
    CreateVolumeControl("BGM", "🎵 배경음 (BGM)", "BgmVolume", body)
    CreateVolumeControl("SFX", "🔊 효과음 (SFX)", "SfxVolume", body)

    -- 3. 최적화 단계 (순환 토글)
    local optBtn = PopupLayout.CreateButton("OptLevel", "최적화 단계", body)
    local function refreshOpt()
        local lv = SettingsService.GetSettings().OptimizationLevel or 0
        local txt = (lv == 0 and "고품질" or lv == 1 and "성능우선" or "초절전")
        optBtn.Text = "최적화: " .. txt
        optBtn.TextColor3 = UITheme.Colors.Accent
    end
    optBtn.MouseButton1Click:Connect(function()
        local nextLv = ((SettingsService.GetSettings().OptimizationLevel or 0) + 1) % 3
        SettingsService:UpdateSetting("OptimizationLevel", nextLv)
        refreshOpt()
    end)
    refreshOpt()

    Logger.Info("[SettingsUI] 프리미엄 수술 완료.🚩")
end

function SettingsUI.Init()
    Logger.Info("[SettingsUI] 초기화 및 Registry 등록 중...")
    UIEvents.Register("SettingsUI", SettingsUI)
    
    -- [최적화] 프리로딩을 통해 클릭 지연 방지
    task.spawn(function()
        SettingsUI.Create()
    end)
end

function SettingsUI.Open()
    Logger.Info("[SettingsUI] Open 호출됨")
    if not popup then 
        Logger.Info("[SettingsUI] Popup이 없어 생성 시도")
        SettingsUI.Create() 
    end
    if popup then 
        Logger.Info("[SettingsUI] Popup 애니메이션 실행")
        popup.Open() 
    else
        Logger.Error("[SettingsUI] Popup 생성 실패")
    end
end

function SettingsUI.Close()
    if popup then popup.Close() end
end

function SettingsUI.Toggle()
    if not popup then SettingsUI.Create() end
    if popup.ScreenGui.Enabled then -- [수정] 🚩
        SettingsUI.Close()
    else
        SettingsUI.Open()
    end
end

return SettingsUI
