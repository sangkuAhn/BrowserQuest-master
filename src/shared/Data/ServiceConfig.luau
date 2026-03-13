--!strict
--[[
    [ServiceConfig.luau] - MVP (Phase 1) 셋업
    기본 사냥, 전투, 레벨업, 인벤토리만 활성화된 최소 기능 버전입니다.
    REFRESH_SYNC_TOKEN: 20260312_1330
]]

--]]

-- [🚩 MASTER CONTROL FLAGS]
-- [[ ⚠️ 관리 지침 (Critical Management Policy) ]]
-- 1. 새로운 서비스 변수가 추가되거나 변경될 때, 상호 의존성이 있는 서비스들은 반드시 마스터 변수(FLAG_*)로 묶어서 관리하십시오.
-- 2. 해당 지침과 마스터 변수 구조는 시스템의 일관성을 위해 소스 수정 시에도 항상 유지되어야 합니다.
-- 3. 관련 있는 서비스들을 한 번에 제어하여 관리 효율성을 극대화하는 것이 SS등급 아키텍처의 핵심입니다.

local FLAG_MINIMAP    = true  -- 미니맵 (Controller + UI)
local FLAG_COMBAT     = true  -- 전투 시스템 (Core + Input + VFX)
local FLAG_MONSTER    = true  -- 몬스터 엔진 (Manager + Service + Render)
local FLAG_INVENTORY  = true  -- 가방 및 캐릭터 정보
local FLAG_CHAT       = true  -- 채팅 시스템 (Service + Log)
local FLAG_HUD        = true  -- 메인 HUD (HUD + Status + SideMenu)

-- [신규] UI 배치 타입 정의 🚩
export type UIPlacement = "Right" | "Bottom" | "Both"

local ServiceConfig = {
    -- [🟢 ACTIVE SERVICES]
    DataService         = true,  -- [DataService] 데이터 저장 및 로드 관리 (MongoDB/Memory)
    PlayerService       = true,  -- [PlayerService] 플레이어 데이터 세션 및 상태 관리
    AdminService        = true,  -- [AdminService] 서버 관리 도구 및 명령어 처리
    StartupService      = true,  -- [StartupService] 서버 시작 초기화 및 데이터 프리로딩
    NetworkManager      = true,  -- [NetworkManager] 서버-클라이언트 패킷 통신 최적화 레이어
    AreaManager         = true,  -- [AreaManager] 지역(Zone) 데이터 및 스폰 구역 관리
    AnalyticsManager    = true,  -- [AnalyticsManager] 게임 지표 수집 및 분석
    AntiCheatService    = true,  -- [AntiCheatService] 비정상 행위 감지 및 차단
    AudioController     = true,  -- [AudioController] 상황별 배경음 및 효과음 제어
    VFXPool             = true,  -- [VFXPool] 이펙트 리소스 풀링 및 퍼포먼스 관리

    -- [Legion & Combat]
    MonsterManager      = FLAG_MONSTER,  -- [MonsterManager] 서버측 몬스터 스폰 및 개체수 제어
    MonsterService      = FLAG_MONSTER,  -- [MonsterService] 몬스터 AI 및 행동 트리 처리
    LegionBridge        = FLAG_MONSTER,  -- [LegionBridge] 몬스터 엔진과 코어 시스템 연결 브릿지
    EntityFactory       = true,  -- [EntityFactory] 개체(몬스터/NPC) 생성 팩토리
    ItemFactory         = true,  -- [ItemFactory] 아이템 객체 생성 및 속성 부여
    CombatService       = FLAG_COMBAT,   -- [CombatService] 서버 정밀 데미지 판정 및 전투 로직
    ProjectileService   = FLAG_COMBAT,   -- [ProjectileService] 투사체 궤적 및 충돌 판정
    AreaService         = true,  -- [AreaService] 지역 진입/이탈 이벤트 처리
    WorldSpawnService   = true,  -- [WorldSpawnService] 월드 내 오브젝트 및 몹 스폰 관리
    WaveService         = false, -- [WaveService] 웨이브 기반 방어 시스템 (상시 스폰으로 대체됨)

    -- [Client Core Controllers]
    CombatController    = FLAG_COMBAT,   -- [CombatController] 클라이언트 전투 입력 및 타격 연출
    VFXController       = true,  -- [VFXController] 클라이언트 시각 효과 발생기
    HUDService          = FLAG_HUD,      -- [HUDService] 메인 화면 UI 요소 통합 관리 (Mediator)
    InventoryUI         = { Enabled = FLAG_INVENTORY, Placement = "Both" }, -- [수정] 상세 설정 구조로 변경 🚩
    MinimapController   = FLAG_MINIMAP,  -- [MinimapController] 지형 가이드 및 실시간 위치 표시 🚩
    MinimapUI           = FLAG_MINIMAP,  -- [MinimapUI] 화면 우측 상단 원형 미니맵 렌더링 🚩
    SkillUI             = { Enabled = true, Placement = "Both" },
    ServerAdminUI       = { Enabled = true, Placement = "Right" },
    SettingsUI          = { Enabled = true, Placement = "Both" },
    CharacterInfoUI     = { Enabled = FLAG_INVENTORY, Placement = "Both" },
    StatusUIService     = { Enabled = true, Placement = "Both" },
    SettingsService     = true,  -- [SettingsService] 클라이언트 설정 저장 및 동기화
    MonsterRenderer     = FLAG_MONSTER,  -- [MonsterRenderer] 몬스터 모델 로딩 및 클라이언트 렌더링
    CombatInput         = FLAG_COMBAT,   -- [CombatInput] 전투 키 입력 바인딩 및 반응 처리
    CombatVFX           = FLAG_COMBAT,   -- [CombatVFX] 전투 시 발동되는 전용 시각 효과
    BodyMovement        = true,  -- [BodyMovement] 물리 기반 캐릭터 이동 및 관성 처리
    MonsterAnimate      = false, -- [MonsterAnimate] 몬스터 애니메이션 시스템

    -- [Economy & Social]
    EconomyService      = true,  -- [EconomyService] 재화(골드/젬) 거래 및 데이터 관리
    ChatService         = FLAG_CHAT,     -- [ChatService] 채팅 시스템 통신 및 필터링
    OverheadBarController = true, -- [OverheadBarController] 캐릭터 머리 위 HP/이름 바 제어
    ChatLogController   = FLAG_CHAT,     -- [ChatLogController] 채팅 로그 기록 및 UI 연출
    SideMenuUI          = FLAG_HUD,      -- [SideMenuUI] 사이드바 메뉴 메뉴 버튼 제어
    StatusBarUI         = FLAG_HUD,      -- [StatusBarUI] 하단 상태바(HP/MP/EXP) 전용 관리
    SkillBarUI          = true,  -- [SkillBarUI] 하단 스킬 퀵슬롯 바 제어
    SprintingController = true,  -- [SprintingController] 달리기 및 스테미나 소모 처리

    -- [🔴 DISABLED SERVICES]
    QuestService        = false,
    AchievementService  = false,
    TutorialService     = false,
    RaidService         = false,
    TowerService        = false,
    EnchantService      = false,
    SkillService        = false,
    ClassService        = false,
    TitleService        = false,
    CostumeService      = false,
    MountService        = false,
    PetService          = false,
    PortalService       = false,
    PartyService        = false,
    DailyService        = false,
    ResourceService     = false,
    EnvironmentService  = false,
    ShopService         = false,
    TradeService        = false,
    AuctionService      = false,
    RankingService      = false,
    MailService         = false,
    GachaService        = false,
    BattlePassService   = false,
    MonetizationService = false,
    ClanService         = false,
    ClanArenaService    = false,
}

return ServiceConfig