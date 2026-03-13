--!strict
--[[
    [Framework.luau]
    서비스의 생명주기와 의존성을 관리하는 중앙 프레임워크입니다.
    의존성 주입(DI) 및 서비스 검색 기능을 제공합니다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Core"):WaitForChild("Logger"))
local ServiceConfig = require(Shared:WaitForChild("Data"):WaitForChild("ServiceConfig"))

type Service = {
    Name: string,
    Init: ((self: any) -> ())?,
    Start: ((self: any) -> ())?,
    [string]: any,
}

local Framework = {
    _services = {} :: { [string]: Service },
    _initialized = false,
    _started = false,
}

-- 서비스 등록
function Framework.RegisterService(service: Service)
    warn("[Framework] 서비스 등록 요청: " .. (service.Name or "Unknown"))
    if Framework._services[service.Name] then
        Logger.Warn(string.format("[Framework] 서비스 '%s'가 이미 등록되어 있습니다.", service.Name))
        return
    end

    -- 설정에 관계없이 서비스 객체 자체는 등록함 (GetService 시 '찾을 수 없음' 에러 방지)
    Framework._services[service.Name] = service
    
    local isEnabled = ServiceConfig[service.Name]
    
    -- [Whitelist 방식] ServiceConfig에 명시되지 않은 경우 기본적으로 비활성(false) 처리
    if isEnabled == nil then
        isEnabled = false
        ServiceConfig[service.Name] = false
    end

    if isEnabled == false then
        service._disabled = true -- 서비스 객체에 명시적으로 비활성 마크 부착
        Logger.Info(string.format("[Framework] 서비스 등록됨 (비활성 상태): %s", service.Name))
    else
        Logger.Debug(string.format("[Framework] 서비스 등록됨: %s", service.Name))
    end
end

-- 서비스 검색 (Dependency Injection 포인트)
function Framework.GetService(name: string): any
    local service = Framework._services[name]
    
    -- 서비스가 존재하지만 비활성화 상태인 경우, 안전한 더미 프록시 객체 반환
    if service and service._disabled then
        return setmetatable({}, {
            __index = function(t, key)
                -- 어떤 함수를 호출하든 에러 없이 조용히 넘어가는 빈 함수 반환
                return function(...)
                    -- 필요 시 여기서 로깅 가능
                end
            end
        })
    end

    if not service then
        Logger.Error(string.format("[Framework] '%s' 서비스를 찾을 수 없습니다.", name))
        return nil
    end

    return service
end

-- 모든 서비스 초기화
function Framework.Init()
    if Framework._initialized then return end
    Framework._initialized = true
    
    Logger.Info("[Framework] 모든 서비스 초기화 중...")
    
    -- 1단계: 모든 서비스의 Init 호출
    for name, service in pairs(Framework._services) do
        -- 활성화된 서비스만 Init 호출
        local isEnabled = ServiceConfig[name] ~= false
        warn(string.format("[Framework] 서비스 '%s' 초기화 시도 (Enabled: %s)", name, tostring(isEnabled)))
        
        if isEnabled then
                local initFunc = service.Init
                if type(initFunc) == "function" then
                    warn(string.format("[Framework] '%s' Init 함수 실행 중...", name))
                    local success, err = pcall(function()
                        if type(initFunc) == "function" then
                            initFunc(service)
                        end
                    end)
                    if not success then
                        Logger.Error(string.format("[Framework] '%s' 초기화 오류: %s", service.Name, err))
                    end
                else
                    warn(string.format("[Framework] '%s'는 Init 함수가 없습니다.", name))
                end
        end
    end
end

-- 모든 서비스 시작
function Framework.Start()
    if Framework._started then return end
    Framework._started = true
    
    if not Framework._initialized then
        Framework.Init()
    end
    
    Logger.Info("[Framework] 모든 서비스 시작 중...")
    
    -- 2단계: 모든 서비스의 Start 호출 (비동기)
    for name, service in pairs(Framework._services) do
        -- 활성화된 서비스만 Start 호출
        if ServiceConfig[name] ~= false then
                local startFunc = service.Start
                if type(startFunc) == "function" then
                    task.spawn(function()
                        local success, err = pcall(function()
                            startFunc(service)
                        end)
                        if not success then
                            Logger.Error(string.format("[Framework] '%s' 시작 오류: %s", service.Name, err))
                        end
                    end)
                end
        end
    end
end

-- 서비스 등록 여부 확인
function Framework.IsServiceRegistered(name: string): boolean
    return Framework._services[name] ~= nil
end

return Framework
