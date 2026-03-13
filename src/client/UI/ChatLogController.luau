--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Core"):WaitForChild("Logger"))
local UIEvents = require(Shared:WaitForChild("Core"):WaitForChild("UIEvents")) -- [추가] 🚩

local ChatLogController = {}

local LOG_WIDTH = 300
local LOG_HEIGHT = 180
local PANEL_X = 20
local PANEL_Y = -30 
local MAX_MESSAGES = 30

local _chatGui: ScreenGui?
local chatPanel: Frame?
local chatFrame: ScrollingFrame?
local inputField: TextBox?
local sendBtn: TextButton?

function ChatLogController.SetVisible(visible: boolean)
    if chatPanel then
        chatPanel.Visible = visible
    end
end

function ChatLogController.AddMessage(senderName: string, message: string, color: Color3?)
    if not chatFrame then return end
    local finalColor = color or Color3.fromRGB(240, 240, 240)
    local fullText = string.format("[%s]: %s", senderName, message)

    local msgLabel = Instance.new("TextLabel")
    msgLabel.Name = "ChatMessage"
    msgLabel.Size = UDim2.new(1, -10, 0, 0)
    msgLabel.AutomaticSize = Enum.AutomaticSize.Y
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = fullText
    msgLabel.TextColor3 = finalColor
    msgLabel.TextStrokeTransparency = 0.7
    msgLabel.Font = Enum.Font.GothamMedium
    msgLabel.TextSize = 14
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.TextWrapped = true
    msgLabel.Parent = chatFrame

    local children = chatFrame:GetChildren()
    local messages = {}
    for _, child in ipairs(children) do
        if child:IsA("TextLabel") then table.insert(messages, child) end
    end

    if #messages > MAX_MESSAGES then
        table.sort(messages, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        if messages[1] then messages[1]:Destroy() end
    end

    task.defer(function()
        if chatFrame then chatFrame.CanvasPosition = Vector2.new(0, 9999) end
    end)
end

function ChatLogController.AddSystemMessage(message: string)
    ChatLogController.AddMessage("System", message, Color3.fromRGB(255, 230, 100))
end

function ChatLogController.ProcessSendMessage(text: string)
    if text == "" or string.gsub(text, " ", "") == "" then return end
    
    local textChannel = TextChatService:FindFirstChild("RBXGeneral", true) :: TextChannel
    if textChannel then
        textChannel:SendAsync(text)
    else
        Players.LocalPlayer:Chat(text)
    end
end

function ChatLogController.CreateUI()
    local player = Players.LocalPlayer
    local pgui = player:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("CustomChatLog") then return end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CustomChatLog"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 10
    screenGui.Parent = pgui
    _chatGui = screenGui

    local bg = Instance.new("Frame")
    bg.Name = "ChatPanel"
    bg.Size = UDim2.new(0, LOG_WIDTH, 0, LOG_HEIGHT)
    bg.Position = UDim2.new(0, PANEL_X, 1, PANEL_Y)
    bg.AnchorPoint = Vector2.new(0, 1)
    bg.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    bg.BackgroundTransparency = 0.3
    bg.BorderSizePixel = 0
    bg.Visible = true
    bg.Parent = screenGui
    chatPanel = bg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = bg

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 120, 255)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.6
    stroke.Parent = bg

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Scroll"
    scroll.Size = UDim2.new(1, -16, 1, -55)
    scroll.Position = UDim2.new(0, 8, 0, 8)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    scroll.Parent = bg
    chatFrame = scroll

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 5)
    pad.PaddingRight = UDim.new(0, 5)
    pad.Parent = scroll

    local inputContainer = Instance.new("Frame")
    inputContainer.Name = "InputContainer"
    inputContainer.Size = UDim2.new(1, -16, 0, 35)
    inputContainer.Position = UDim2.new(0, 8, 1, -8)
    inputContainer.AnchorPoint = Vector2.new(0, 1)
    inputContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    inputContainer.BackgroundTransparency = 0.5
    inputContainer.Parent = bg
    
    local iCorner = Instance.new("UICorner")
    iCorner.CornerRadius = UDim.new(0, 6)
    iCorner.Parent = inputContainer

    local field = Instance.new("TextBox")
    inputField = field
    field.Name = "InputField"
    field.Size = UDim2.new(1, -55, 1, -4)
    field.Position = UDim2.new(0, 8, 0, 2)
    field.BackgroundTransparency = 1
    field.Font = Enum.Font.Gotham
    field.Text = ""
    field.PlaceholderText = "메세지 입력... (Enter)"
    field.PlaceholderColor3 = Color3.fromRGB(180, 180, 180)
    field.TextColor3 = Color3.new(1, 1, 1)
    field.TextSize = 14
    field.TextXAlignment = Enum.TextXAlignment.Left
    field.ClearTextOnFocus = false
    field.Parent = inputContainer

    local btn = Instance.new("TextButton")
    sendBtn = btn
    btn.Name = "SendBtn"
    btn.Size = UDim2.new(0, 45, 0, 28)
    btn.Position = UDim2.new(1, -48, 0.5, 0)
    btn.AnchorPoint = Vector2.new(0, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(70, 100, 255)
    btn.BackgroundTransparency = 0.3
    btn.Text = "Enter"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = inputContainer
    
    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 4)
    sCorner.Parent = sendBtn

    local function performFinalSend(inputField: TextBox)
        if inputField.Text == "" then return end
        inputField.Text ..= " "
        RunService.Heartbeat:Wait()
        local finalMessage = string.sub(inputField.Text, 1, -2)
        inputField.Text = "" 
        ChatLogController.ProcessSendMessage(finalMessage)
        task.defer(function()
            if inputField then inputField:CaptureFocus() end
        end)
    end

    if inputField then
        inputField.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                inputField.CursorPosition = string.len(inputField.Text) + 1
                performFinalSend(inputField)
            end
        end)
    end

    if sendBtn and inputField then
        sendBtn.MouseButton1Click:Connect(function()
            if inputField:IsFocused() then
                inputField:ReleaseFocus()
            else
                performFinalSend(inputField)
            end
        end)
    end
end

-- [반응형] 화면 크기에 따른 채팅창 레이아웃 업데이트 🚩
function ChatLogController.UpdateLayout(mode: string)
    if not chatPanel or not chatFrame or not inputField then return end
    
    local isMobile = (mode == "Mobile")
    local width = isMobile and 200 or 260 -- 너비 추가 축소 🚩
    local height = isMobile and 110 or 150 -- 높이 추가 축소 🚩
    local textSize = isMobile and 11 or 12
    
    chatPanel.Size = UDim2.new(0, width, 0, height)
    chatPanel.Position = UDim2.new(0, 10, 1, -25) -- 위치 살짝 올림 🚩
    
    -- 기존 메시지들 폰트 크기 조정
    for _, child in ipairs(chatFrame:GetChildren()) do
        if child:IsA("TextLabel") then
            child.TextSize = textSize
        end
    end
    
    Logger.Debug(string.format("[ChatLogController] 반응형 레이아웃 적용: %s", mode))
end

function ChatLogController.Init()
    Logger.Info("[ChatLogController] 커서 고정 버전 초기화 중...")
    
    -- ✅ [해결] 인벤토리를 강제로 켜던 코드를 완전히 삭제했습니다.
    -- 이제 기본 인벤토리는 StartupController에서 정한 대로 꺼진 상태를 유지합니다.
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) -- 기본 채팅창만 확실히 끕니다.
    end)

    local chatWindow = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
    if chatWindow then
        chatWindow.Enabled = false 
    end
    
    ChatLogController.CreateUI()
    
    -- 초기 모드 전송 🚩
    local ResponsiveManager = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Core"):WaitForChild("ResponsiveManager"))
    ChatLogController.UpdateLayout(ResponsiveManager.GetMode())
    
    -- 반응형 신호 구독 🚩
    UIEvents.Get("OnScreenModeChanged").Event:Connect(function(data)
        ChatLogController.UpdateLayout(data.Mode)
    end)
    
    local function onPlayerAdded(player: Player)
        player.Chatted:Connect(function(message)
            ChatLogController.AddMessage(player.DisplayName or player.Name, message)
        end)
    end
    
    for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end
    Players.PlayerAdded:Connect(onPlayerAdded)
    
    UserInputService.InputBegan:Connect(function(input, processed)
        if input.KeyCode == Enum.KeyCode.Slash and not processed then
            task.wait()
            if inputField then
                inputField:CaptureFocus()
                inputField.Text = ""
            end
        end
    end)

    ChatLogController.AddSystemMessage("채팅 시스템이 최적화되었습니다.")
end

return ChatLogController