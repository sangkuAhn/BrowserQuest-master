--!strict
--[[
    [MinimapUI.luau]
    화면 우측 상단에 표시되는 원형 레이더(미니맵) 렌더링 전용 스크립트입니다.
    플레이어 (중앙 직사각형) 및 NPC/몬스터를 색상 점 형태로 표시합니다.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MinimapUI = {}

local radarBg: Frame? = nil
local radarCanvas: Frame? = nil -- 점들을 넣을 컨테이너 
local markers: {[Instance]: Frame} = {} -- 타겟별 점 UI 추적
local MAP_SIZE = 160 -- 레이더의 너비/높이
local BLIP_SIZE = 6

function MinimapUI.Create()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MinimapUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true -- [신규] 화면 최상단(TopBar) 영역까지 UI 배치 허용
    
    -- 원형의 뒷배경 컨테이너
    radarBg = Instance.new("Frame")
    local bg = radarBg :: Frame
    bg.Name = "RadarBackground"
    bg.Size = UDim2.new(0, MAP_SIZE, 0, MAP_SIZE)
    -- 화면 우측 상단 배치 (좌측 메뉴 아이콘 높이에 맞춤 + 우측 여백)
    bg.Position = UDim2.new(1, -MAP_SIZE - 15, 0, 12)
    bg.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    bg.BackgroundTransparency = 0.4
    bg.ClipsDescendants = true -- 원을 벗어나는 점들을 자름
    bg.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0) -- 완벽한 원 (50%)
    corner.Parent = bg

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(150, 150, 200)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = bg
    
    -- 방위 N 북쪽 마크
    local nMark = Instance.new("TextLabel")
    nMark.Size = UDim2.new(0, 20, 0, 20)
    nMark.Position = UDim2.new(0.5, -10, 0, 0)
    nMark.BackgroundTransparency = 1
    nMark.Font = Enum.Font.GothamBold
    nMark.TextSize = 14
    nMark.TextColor3 = Color3.fromRGB(240, 200, 50)
    nMark.Text = "N"
    nMark.Parent = bg
    
    -- 중앙 내 캐릭터 표시
    local centerBlip = Instance.new("Frame")
    centerBlip.Size = UDim2.new(0, BLIP_SIZE*1.2, 0, BLIP_SIZE*1.2)
    centerBlip.Position = UDim2.new(0.5, -BLIP_SIZE*0.6, 0.5, -BLIP_SIZE*0.6)
    centerBlip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    centerBlip.ZIndex = 10
    centerBlip.Parent = bg
    
    -- 동적으로 돌아가며 마커를 담을 회전 캔버스
    radarCanvas = Instance.new("Frame")
    local canvas = radarCanvas :: Frame
    canvas.Name = "Canvas"
    canvas.Size = UDim2.new(1, 0, 1, 0)
    canvas.BackgroundTransparency = 1
    canvas.AnchorPoint = Vector2.new(0.5, 0.5)
    canvas.Position = UDim2.new(0.5, 0, 0.5, 0)
    canvas.Parent = bg

    screenGui.Parent = playerGui
    return MinimapUI
end

-- [반응형] 화면 크기에 따른 미니맵 리사이징 🚩
function MinimapUI.UpdateLayout(mode: string, isCompact: boolean?)
    if not radarBg then return end
    
    local size = (mode == "Mobile" or isCompact) and 110 or 160 -- 더 작게 🚩
    radarBg.Size = UDim2.new(0, size, 0, size)
    radarBg.Position = UDim2.new(1, -size - 12, 0, 12)
    MAP_SIZE = size
end

-- [API] 미니맵의 하단 Y 좌표(Offset) 반환 🚩
function MinimapUI.GetBottom(): number
    if not radarBg then return 0 end
    return radarBg.Position.Y.Offset + radarBg.Size.Y.Offset
end

-- 카메라와의 Y축 회전 오프셋 (단위: Degree) 갱신
function MinimapUI.UpdateRotation(cameraRotationY: number)
    if radarCanvas then
        radarCanvas.Rotation = -math.deg(cameraRotationY)
    end
end

-- 대상의 종류에 따른 색상 점 렌더링
function MinimapUI.UpdateMarker(targetInst: Instance, localX: number, localZ: number, scale: number, markType: "Monster" | "NPC" | "Player")
    if not radarCanvas then return end
    
    local blip = markers[targetInst]
    if not blip then
        blip = Instance.new("Frame")
        blip.Size = UDim2.new(0, BLIP_SIZE, 0, BLIP_SIZE)
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = blip
        
        if markType == "Monster" then
            blip.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- 빨간점
        elseif markType == "NPC" then
            blip.BackgroundColor3 = Color3.fromRGB(50, 255, 50) -- 초록점
        else
            blip.BackgroundColor3 = Color3.fromRGB(100, 150, 255) -- 다른 유저는 파란점
        end
        blip.Parent = radarCanvas
        markers[targetInst] = blip
    end
    
    -- 0.5 (중앙) 기준으로 X, Z 거리 스케일링 적용
    local uiX = 0.5 + (localX / scale)
    local uiY = 0.5 + (localZ / scale)
    
    blip.Position = UDim2.new(uiX, -BLIP_SIZE/2, uiY, -BLIP_SIZE/2)
end

function MinimapUI.RemoveMarker(targetInst: Instance)
    local blip = markers[targetInst]
    if blip then
        blip:Destroy()
        markers[targetInst] = nil
    end
end

return MinimapUI
