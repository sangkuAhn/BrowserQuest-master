--!strict
--[[
    [ClientEntry.client.luau]
    클라이언트 측 메인 진입점 스크립트입니다.
    현대적 아키텍처(Framework & Runner)를 통해 모든 클라이언트 서비스를 자동으로 가동합니다.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ClientRunner = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Core"):WaitForChild("ClientRunner"))

-- [Best Practice] 게임 시작 즉시 모든 기본 UI 차단 (깜빡임 최소화)
pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) -- 채팅은 ChatLogController가 관리하되 엔진 레벨에서 켜둠
end)

-- 클라이언트 프레임워크 및 모든 서비스 시작
ClientRunner.Start()
