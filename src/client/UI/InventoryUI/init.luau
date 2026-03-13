--!strict
--[[
    [InventoryUI.luau]
    사용자의 인벤토리 UI를 관리합니다.
    PopupLayout을 활용하여 디자인을 통일하고, 그리드 형태의 아이템 슬롯을 제공합니다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PopupLayout = require(Shared:WaitForChild("Core"):WaitForChild("PopupLayout"))
local Logger = require(Shared:WaitForChild("Core"):WaitForChild("Logger"))
local UIEvents = require(Shared:WaitForChild("Core"):WaitForChild("UIEvents")) -- [추가] 🚩
local L = require(Shared:WaitForChild("Core"):WaitForChild("LanguageManager")) -- [번역]
local ItemData = require(Shared:WaitForChild("Data"):WaitForChild("ItemData"))
local Framework = require(Shared:WaitForChild("Core"):WaitForChild("Framework"))

local _HUDService = nil

local InventoryUI = {}
InventoryUI.Info = { id = "InventoryUI", icon = "🎒", name = "인벤토리" } -- [추가] 🚩
local elements: any = nil
local _player = Players.LocalPlayer

local MAX_SLOTS = 20 -- 기본으로 생성해둘 슬롯 개수
local GRID_PADDING = 5 -- [신규] 테두리가 잘리지 않도록 하는 전체 여백
local BORDER_THICKNESS = 2.5 -- [신규] 장착 테두리 굵기

function InventoryUI.Init()
    Logger.Info("[InventoryUI] 초기화 시작...")
    HUDService = Framework.GetService("HUDService")
    VFXController = Framework.GetService("VFXController")
    
    -- [Registry] 자신을 등록 🚩
    UIEvents.Register("InventoryUI", InventoryUI)

    -- UI를 미리 생성하여 지연 없이 즉시 오픈 가능하도록 함 (프리로딩) 🚩
    task.spawn(function()
        InventoryUI.Create()
        Logger.Info("[InventoryUI] 프리로딩 및 Registry 등록 완료.")
    end)
end

-- 인벤토리 창 생성/열기
function InventoryUI.Create()
    if elements then
        InventoryUI.Toggle() -- 기존 코드가 Toggle 방식으로 작동하도록 유도
        return
    end

    elements = PopupLayout.CreateLayout1({
        Name = "InventoryGui",
        Title = "INVENTORY",
        HasTabs = true,
        HasFooter = false,
        Size = UDim2.new(0, 400, 0, 500),
        Position = UDim2.new(0.5, 160, 0.5, 0) -- 화면 중앙 기준 약간 우측에 배치 🚩
    })

    if not elements then return end
    
    -- [가이드] 생성 직후 닫힌 상태 보장
    task.defer(function()
        if elements then elements.Close() end
    end)
    
    -- [투명 배경 설정]
    elements.MainFrame.BackgroundTransparency = 0.3
    elements.ContentFrame.BackgroundTransparency = 1

    -- 탭 구성 (장비 / 소비품 / 재료 등)
    InventoryUI.SetupTabs()
    
    -- 슬롯 그리드 설정
    InventoryUI.SetupGrid()

    -- [최적화] 서버 데이터 동기화 대기를 비동기로 처리하여 UI 생성을 방해하지 않음🚩
    task.spawn(function()
        local network = ReplicatedStorage:WaitForChild("Network", 5)
        if not network then return end
        
        local syncEvent = network:WaitForChild("SyncPlayerData", 5) :: RemoteEvent
        if syncEvent then
            syncEvent.OnClientEvent:Connect(function(data)
                if data and data.Inventory then
                    Logger.Debug("[InventoryUI] 서버로부터 인벤토리 데이터 수신 (아이템 수: " .. #data.Inventory .. ")")
                    InventoryUI.UpdateSlots(data.Inventory, data.Equipped or {})
                end
            end)
        end
    end)
    
    Logger.Info("[InventoryUI] 인벤토리 UI 생성 완료.")
end

function InventoryUI.SetupTabs()
    if not (elements and elements.TabScroll) then return end
    
    local function createTab(name: string, order: number)
        local btn = PopupLayout.CreateButton("Tab_"..name, name, elements.TabScroll)
        btn.LayoutOrder = order
    end

    createTab("EQUIP", 1)
    createTab("ITEM", 2)
    createTab("QUEST", 3)
end

function InventoryUI.SetupGrid()
    if not elements then return end
    
    local content = elements.ContentFrame
    local list = content:FindFirstChildOfClass("UIListLayout")
    if list then list:Destroy() end

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 70, 0, 70)
    grid.CellPadding = UDim2.new(0, 10, 0, 10)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = content

    -- [신규] 테두리 잘림 방지를 위한 Padding 추가
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, GRID_PADDING)
    padding.PaddingRight = UDim.new(0, GRID_PADDING)
    padding.PaddingTop = UDim.new(0, GRID_PADDING)
    padding.PaddingBottom = UDim.new(0, GRID_PADDING)
    padding.Parent = content

    -- 테스트 슬롯 생성
    for i = 1, MAX_SLOTS do
        local slot = Instance.new("Frame")
        slot.Name = "Slot_" .. i
        slot.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        slot.BorderSizePixel = 0
        slot.Parent = content
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = slot

        -- [중요] 그리드 레이아웃 내부의 크기 애니메이션을 위한 요소
        local uiScale = Instance.new("UIScale")
        uiScale.Parent = slot

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 200, 0)
        stroke.Thickness = BORDER_THICKNESS
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Enabled = false
        stroke.Parent = slot

        -- 아이콘 (미리 만들어두고 숨김 처리)
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0.7, 0, 0.7, 0)
        icon.Position = UDim2.new(0.5, 0, 0.45, 0)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.ZIndex = 2
        icon.Visible = false
        icon.Parent = slot

        -- 텍스트 라벨 (미리 만들어두고 구조 고정)
        local label = Instance.new("TextLabel")
        label.Name = "ItemNameLabel"
        label.Size = UDim2.new(1, 0, 0, 15)
        label.Position = UDim2.new(0, 0, 1, -18)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(230, 230, 230)
        label.Font = Enum.Font.LuckiestGuy
        label.TextSize = 10
        label.TextWrapped = true
        label.ZIndex = 3
        label.Text = ""
        label.Parent = slot
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.ZIndex = 5
        btn.Parent = slot
        
        -- 인터랙션 이벤트: Scale 값을 트윈하여 안전하게 크기 조절
        btn.MouseButton1Click:Connect(function()
            local itemId = slot:GetAttribute("ItemId")
            if itemId then
                TweenService:Create(uiScale, TweenInfo.new(0.05), {Scale = 0.9}):Play()
                task.delay(0.05, function()
                    TweenService:Create(uiScale, TweenInfo.new(0.1), {Scale = 1}):Play()
                end)
                InventoryUI.OnSlotClicked(itemId :: string)
            end
        end)

        btn.MouseEnter:Connect(function()
            TweenService:Create(slot, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 50, 70)}):Play()
            if slot:GetAttribute("ItemId") then
                TweenService:Create(uiScale, TweenInfo.new(0.1), {Scale = 1.05}):Play()
            end
        end)
        
        btn.MouseLeave:Connect(function()
            TweenService:Create(slot, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
            TweenService:Create(uiScale, TweenInfo.new(0.1), {Scale = 1.0}):Play()
        end)
    end
end

-- 슬롯 업데이트 (데이터 기반)
function InventoryUI.UpdateSlots(inventory: {string}, equipped: {Weapon: string?, Armor: string?})
    if not elements then return end
    local content = elements.ContentFrame
    
    -- 1. 모든 슬롯 초기화 (깨끗하게 비우기)
    for _, slot in ipairs(content:GetChildren()) do
        if slot:IsA("Frame") and string.match(slot.Name, "Slot_") then
            slot:SetAttribute("ItemId", nil)
            
            local lbl = slot:FindFirstChild("ItemNameLabel") :: TextLabel
            if lbl then lbl.Text = "" end
            
            local icon = slot:FindFirstChild("Icon") :: ImageLabel
            if icon then icon.Visible = false end

            local stroke = slot:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Enabled = false end
        end
    end

    -- 2. 가지고 있는 아이템 정보 채우기
    for i, itemId in ipairs(inventory) do
        local slot = content:FindFirstChild("Slot_" .. i)
        if slot then
            local data = ItemData.GetItemData(itemId)
            if data then
                slot:SetAttribute("ItemId", itemId)
                
                local lbl = slot:FindFirstChild("ItemNameLabel") :: TextLabel
                if lbl then lbl.Text = L.get(data.NameKey) end
                
                local icon = slot:FindFirstChild("Icon") :: ImageLabel
                if icon then 
                    icon.Image = data.IconId or ""
                    icon.Visible = true
                end
                
                local stroke = slot:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Enabled = (equipped.Weapon == itemId or equipped.Armor == itemId)
                end
            end
        end
    end
end

function InventoryUI.OnSlotClicked(itemId: string)
    local data = ItemData.GetItemData(itemId)
    if not data then return end
    
    Logger.Info(string.format("[InventoryUI] 아이템 클릭: %s (%s)", data.NameKey or data.Id, data.Type))
    
    -- 안전하게 VFXController 호출 (비활성화 상태 대비)
    if VFXController and VFXController.PlayEquipEffect then
        VFXController.PlayEquipEffect()
    end

    local useItemEvent = ReplicatedStorage:WaitForChild("Network"):FindFirstChild("UseItemRequest") :: RemoteEvent
    if useItemEvent then
        useItemEvent:FireServer(itemId)
    end
end

function InventoryUI.Toggle()
    Logger.Info("[InventoryUI] 인벤토리 토글 요청")
    if not elements then
        InventoryUI.Create()
    end
    
    -- 이제 모든 제어는 HUDService에서 수행함.
    if elements then
        if elements.ScreenGui.Enabled then
            InventoryUI.Close()
        else
            InventoryUI.Open()
        end
    end
end

-- 오픈/클로즈 래핑
function InventoryUI.Open()
    if not elements then InventoryUI.Create() end
    if elements then 
        elements.Open() 
        UIEvents.Get("Inventory_State"):Fire(true) -- [추가] 인벤토리 오픈 신호 전송 🚩
    end
end

function InventoryUI.Close()
    if elements then 
        elements.Close() 
        UIEvents.Get("Inventory_State"):Fire(false) -- [추가] 인벤토리 클로즈 신호 전송 🚩
    end
end

return InventoryUI