--!strict
--[[
    [MinimapController.luau]
    레이더 반경 내의 엔티티 위치를 스캔하고 2D 미니맵 UI에 오프셋을 전달하여
    실시간으로 마커(Blip)들이 움직이는 것처럼 연출합니다.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [SS등급 준수] 프레임워크와 로거만 최상단 로드
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Framework = require(Shared:WaitForChild("Core"):WaitForChild("Framework"))
local Logger = require(Shared:WaitForChild("Core"):WaitForChild("Logger"))

-- 지연 로딩용 변수 선언
local MinimapUI = nil

local MinimapController = { Name = "MinimapController" }

local RADAR_RANGE = 120 -- 스캔 반경 (Studs)
local trackedInstances: {[Instance]: true} = {}

function MinimapController:Init()
    Logger.Info("[MinimapController:Init] 미니맵 시스템 초기화 및 DI 주입...")
    
    -- [S등급 준수] Framework를 통해 UI 모듈을 안전하게 로드
    MinimapUI = Framework.GetService("MinimapUI")
    
    if MinimapUI and type(MinimapUI.Create) == "function" then
        local success, err = pcall(function()
            MinimapUI.Create()
        end)
        if not success then
            Logger.Error("[MinimapController] MinimapUI 생성 실패: " .. tostring(err))
        end
    else
        Logger.Warn("[MinimapController] MinimapUI 모듈을 찾을 수 없거나 Create 함수가 없습니다.")
        return -- UI가 없으면 실행 중단
    end
    
    -- 매 프레임 위치 계산 (클라이언트 단에서 가볍게 처리)
    RunService.RenderStepped:Connect(function()
        local player = Players.LocalPlayer
        if not player.Character or not player.Character.PrimaryPart then return end
        
        local hrp = player.Character.PrimaryPart
        local rootPos = hrp.Position
        
        -- 카메라가 바라보는 Y축 회전값 추출 (맵 회전 연출용)
        local camCFrame = Workspace.CurrentCamera.CFrame
        local _, camRotY, _ = camCFrame:ToEulerAnglesYXZ()
        
        if MinimapUI and MinimapUI.UpdateRotation then
            MinimapUI.UpdateRotation(camRotY)
        end
        
        -- 현재 프레임 가시성 관리용 테이블
        local currentFrameVisible = {}
        
        -- 콜렉션 태그 기반 스캔 함수
        local function ScanTag(tagName: string, markType: "Monster" | "NPC" | "Player")
            for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
                local targetHRP = inst:FindFirstChild("HumanoidRootPart") :: BasePart
                if targetHRP then
                    local targetPos = targetHRP.Position
                    
                    -- 고도(Y) 무시 평면 좌표 계산
                    local dx = targetPos.X - rootPos.X
                    local dz = targetPos.Z - rootPos.Z
                    local dist = math.sqrt(dx*dx + dz*dz)
                    
                    if dist <= RADAR_RANGE then
                        -- UI 마커 업데이트
                        if MinimapUI and MinimapUI.UpdateMarker then
                            MinimapUI.UpdateMarker(inst, dx, dz, RADAR_RANGE * 2, markType)
                        end
                        currentFrameVisible[inst] = true
                        trackedInstances[inst] = true
                    end
                end
            end
        end
        
        ScanTag("Monster", "Monster")
        ScanTag("NPC", "NPC")
        
        -- 범위를 벗어나거나 파괴된 객체 마커 제거
        for inst, _ in pairs(trackedInstances) do
            if not currentFrameVisible[inst] or not inst:IsDescendantOf(Workspace) then
                if MinimapUI and MinimapUI.RemoveMarker then
                    MinimapUI.RemoveMarker(inst)
                end
                trackedInstances[inst] = nil
            end
        end
    end)
    
    Logger.Info("[MinimapController] 미니맵 렌더링 루프 가동 시작.")
end

return MinimapController