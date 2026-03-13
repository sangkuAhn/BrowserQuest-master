--!strict
-- [Shared/Core/UIEvents.luau]
local UIEvents = {}
local signals: { [string]: BindableEvent } = {}
local registeredModules: { [string]: any } = {}

-- 특정 UI 이름을 토글하라는 범용 신호
function UIEvents.Get(name: string): BindableEvent
    if not signals[name] then
        local event = Instance.new("BindableEvent")
        event.Name = "UIEvent_" .. name
        signals[name] = event
    end
    return signals[name]
end

-- [신규] UI 모듈 동적 등록 (Registry 패턴)
function UIEvents.Register(name: string, module: any)
    registeredModules[name] = module
    -- 등록 시 HUDService 등에 알림이 필요하다면 여기서 신호를 쏠 수도 있음
end

-- [신규] 등록된 모듈 조회
function UIEvents.GetModule(name: string): any?
    return registeredModules[name]
end

-- [신규] 모든 등록된 모듈 이름 목록 반환
function UIEvents.GetRegisteredNames(): {string}
    local names = {}
    for name, _ in pairs(registeredModules) do
        table.insert(names, name)
    end
    return names
end

return UIEvents
