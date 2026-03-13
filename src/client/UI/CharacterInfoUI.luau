--!strict
--[[
    [CharacterInfoUI.luau]
    인벤토리 오픈 시 좌측에 캐릭터의 상세 정보(이름, 레벨, 기초 스탯)를 표시합니다.
    InventoryUI와는 독립적으로 작동하며 UIEvents를 통해 상태를 동기화합니다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PopupLayout = require(Shared:WaitForChild("Core"):WaitForChild("PopupLayout"))
local Logger = require(Shared:WaitForChild("Core"):WaitForChild("Logger"))
local UIEvents = require(Shared:WaitForChild("Core"):WaitForChild("UIEvents"))
local UITheme = require(Shared:WaitForChild("Data"):WaitForChild("UITheme"))
local _L = require(Shared:WaitForChild("Core"):WaitForChild("LanguageManager"))

local CharacterInfoUI = {}
local elements: any = nil
local player = Players.LocalPlayer

-- UI 레벨 라벨 레퍼런스
CharacterInfoUI.NameLabel = nil :: TextLabel?
CharacterInfoUI.LevelLabel = nil :: TextLabel?
CharacterInfoUI.HPLabel = nil :: TextLabel?
CharacterInfoUI.MPLabel = nil :: TextLabel?
CharacterInfoUI.ExpLabel = nil :: TextLabel?

function CharacterInfoUI.Init()
    Logger.Info("[CharacterInfoUI] 초기화 시작...")
    
    -- [Registry] 등록 🚩
    UIEvents.Register("CharacterInfoUI", CharacterInfoUI)

    -- 인벤토리 상태 변화 구독 🚩 (InventoryUI가 Open/Close 시 Fire함)
    UIEvents.Get("Inventory_State").Event:Connect(function(isOpen: boolean)
        if isOpen then
            CharacterInfoUI.Open()
        else
            CharacterInfoUI.Close()
        end
    end)

    -- [신규] 캐릭터 정보창이 단독으로 닫힐 때 인벤토리도 함께 닫히도록 연동 🚩
    task.spawn(function()
        while not elements do task.wait(0.5) end
        elements.OnClosed:Connect(function()
            local inv = UIEvents.GetModule("InventoryUI")
            if inv then inv.Close() end
        end)
    end)

    -- 프리로딩
    task.spawn(function()
        CharacterInfoUI.Create()
    end)
    
    -- 데이터 동기화
    task.spawn(function()
        local network = ReplicatedStorage:WaitForChild("Network", 5)
        if not network then return end
        local syncEvent = network:WaitForChild("SyncPlayerData", 5) :: RemoteEvent
        if syncEvent then
            syncEvent.OnClientEvent:Connect(function(data)
                CharacterInfoUI.Update(data)
            end)
        end
    end)
end

function CharacterInfoUI.Create()
    if elements then return end
    
    -- 인벤토리(400px) 좌측 배치
    -- 인벤토리 왼쪽 끝(-200)과 정보창 오른쪽 끝(Offset + 150) 사이에 20px 간격 유지
    elements = PopupLayout.CreateLayout1({
        Name = "CharacterInfo",
        Title = "CHARACTER INFO",
        Size = UDim2.new(0, 300, 0, 500),
        Position = UDim2.new(0.5, -210, 0.5, 0) -- 인벤토리 바로 좌측에 배치 🚩
    })
    
    -- 생성 직후 닫기 보장
    task.defer(function()
        if elements then elements.Close() end
    end)
    
    elements.MainFrame.BackgroundTransparency = 0.4 -- 약간 더 투명하게 설정
    
    local content = elements.ContentFrame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 20)
    padding.PaddingLeft = UDim.new(0, 15)
    padding.PaddingRight = UDim.new(0, 15)
    padding.Parent = content

    CharacterInfoUI.SetupUI()
end

function CharacterInfoUI.SetupUI()
    if not elements then return end
    local content = elements.ContentFrame
    
    local function createLabel(name: string, text: string, order: number)
        local frame = Instance.new("Frame")
        frame.Name = name .. "_Row"
        frame.Size = UDim2.new(1, 0, 0, 35)
        frame.BackgroundTransparency = 1
        frame.LayoutOrder = order
        frame.Parent = content
        
        local tag = Instance.new("TextLabel")
        tag.Size = UDim2.new(0.4, 0, 1, 0)
        tag.Text = name
        tag.TextColor3 = UITheme.Colors.TextSub
        tag.BackgroundTransparency = 1
        tag.Font = UITheme.Font.Main
        tag.TextSize = 14
        tag.TextXAlignment = Enum.TextXAlignment.Left
        tag.Parent = frame
        
        local val = Instance.new("TextLabel")
        val.Name = "Value"
        val.Size = UDim2.new(0.6, 0, 1, 0)
        val.Position = UDim2.new(0.4, 0, 0, 0)
        val.Text = text
        val.TextColor3 = UITheme.Colors.Accent
        val.BackgroundTransparency = 1
        val.Font = UITheme.Font.Bold
        val.TextSize = 16
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Parent = frame
        
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Position = UDim2.new(0, 0, 1, 0)
        line.BackgroundColor3 = UITheme.Colors.Secondary
        line.BackgroundTransparency = 0.5
        line.BorderSizePixel = 0
        line.Parent = frame
        
        return val
    end
    
    CharacterInfoUI.NameLabel = createLabel("NAME", player.Name, 1)
    CharacterInfoUI.LevelLabel = createLabel("LEVEL", "1", 2)
    CharacterInfoUI.HPLabel = createLabel("HEALTH", "100 / 100", 3)
    CharacterInfoUI.MPLabel = createLabel("MANA", "50 / 50", 4)
    CharacterInfoUI.ExpLabel = createLabel("EXP", "0 %", 5)
end

function CharacterInfoUI.Update(data: any)
    if not (elements and data) then return end
    
    if CharacterInfoUI.LevelLabel then
        CharacterInfoUI.LevelLabel.Text = tostring(data.Level or 1)
    end
    
    if CharacterInfoUI.HPLabel and data.Stats then
        local cur = math.floor(data.Stats.CurrentHealth or 0)
        local max = math.floor(data.Stats.MaxHealth or 100)
        CharacterInfoUI.HPLabel.Text = string.format("%d / %d", cur, max)
    end
    
    if CharacterInfoUI.MPLabel and data.Stats then
        local cur = math.floor(data.Stats.CurrentMana or 0)
        local max = math.floor(data.Stats.MaxMana or 50)
        CharacterInfoUI.MPLabel.Text = string.format("%d / %d", cur, max)
    end
    
    if CharacterInfoUI.ExpLabel and data.Experience then
        local exp = data.Experience or 0
        local nextExp = data.NextExperience or 100
        local percent = (exp / math.max(1, nextExp)) * 100
        CharacterInfoUI.ExpLabel.Text = string.format("%.1f %%", percent)
    end
end

function CharacterInfoUI.Open()
    if not elements then CharacterInfoUI.Create() end
    if elements then elements.Open() end
end

function CharacterInfoUI.Close()
    if elements then elements.Close() end
end

return CharacterInfoUI
