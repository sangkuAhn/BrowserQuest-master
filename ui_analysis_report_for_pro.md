# 📄 NewQuest UI 시스템 기술 분석 보고서 (Expert Review)

본 보고서는 NewQuest 프로젝트의 현재 UI 아키텍처를 전수 조사한 결과입니다. 전문가의 검토를 통해 향후 확장성 및 성능 최적화 방향을 설정하는 데 목적이 있습니다.

---

## 1. 시스템 소스 및 디렉토리 구조 (Source Overview)
UI 시스템은 **Domain-Driven Layering** 원칙을 따르며, 개발자가 시스템 흐름을 파악하기 위해 확인해야 할 전체 소스 파일 목록은 다음과 같습니다.

### 🔌 플랫폼 진입점 및 프레임워크 (Entry & Framework)
- `src/client/ClientEntry.luau`: 클라이언트 측 메인 진입점. 각 서비스 및 컨트롤러 초기화.
- `src/shared/Core/Framework.luau`: 서비스/컨트롤러의 생명주기 관리 및 **의존성 주입(DI)** 엔진.
- `src/shared/Core/UIEvents.luau`: 모듈 간 통신용 **시그널 중계기**. Registry 패턴을 통한 느슨한 결합 구현.

### 🎨 UI 레이아웃 엔진 및 스타일 (Layout & Styles)
- `src/shared/Core/PopupLayout.luau`: **UI 핵심 렌더링 엔진**. 표준화된 팝업 레이아웃, 애니메이션, 드래그 로직 내장.
- `src/shared/Data/UITheme.luau`: 색상, 폰트, 애니메이션 커브, 사운드 등 공통 **디자인 토큰**.
- `src/shared/Data/ServiceConfig.luau`: UI 메뉴 배치 및 기능 활성화 등에 대한 **전역 설정 데이터**.

### 📱 반응형 시스템 (Responsive Layer)
- `src/client/Core/ResponsiveManager.luau`: 화면 해상도(ViewportSize) 및 기기 특성 실시간 감지 및 `OnScreenModeChanged` 전파.

### 🗺️ HUD 및 인터랙션 서비스 (HUD & UI Services)
- `src/client/UI/HUDService/init.luau`: HUD 요소들을 총괄하는 **중재자(Mediator)** 모듈.
- `src/client/UI/HUDService/SideMenuUI.luau`: 메인 사이드 바. **동적 슬롯 배치** 및 아이콘 전용 모드 전환 로직.
- `src/client/UI/MinimapUI.luau`: **반응형 미니맵 뷰어**. HUD 영역과의 간섭을 고려한 지능형 리사이징 적용.
- `src/client/Systems/MinimapController.luau`: 미니맵의 **데이터 처리 및 마커 연산 로직** 담당.
- `src/client/UI/ChatLogController.luau`: **커스텀 채팅 시스템**. 화면 모드별 가변 너비/높이 및 텍스트 스케일링 적용.

### 팝업 모듈 예시 (UI Component Examples)
- `src/client/UI/InventoryUI/init.luau`: 폴더 구조화된 복잡한 UI의 전형적인 구현 사례.
- `src/client/UI/CharacterInfoUI.luau`: `PopupLayout`을 활용한 표준 팝업 구현 모델.
- `src/client/UI/SettingsUI.luau`: 사용자 설정 및 데이터 연동 UI 예시.

---

## 2. 동작 메커니즘 (Operational Method)
매우 낮은 결합도를 유지하는 **Signal-Driven** 방식을 채택하고 있습니다.

1. **초기화**: `Framework`가 각 UI 모듈의 `Init`을 호출하여 `UIEvents.Register`에 본인을 등록함.
2. **이벤트 발생**: 로직(예: 인벤토리 토글)이 발생하면 `UIEvents.Get("ToggleUI"):Fire("InventoryUI")` 호출.
3. **렌더링**: `PopupLayout.CreateStandardPopup`을 통해 통일된 형태의 UI를 생성하고, `ScreenGui`를 즉시 제어.
4. **상태 동기화**: `UIEvents`를 통해 서로 다른 UI 모듈(예: 가방-캐릭터창)이 `OnClosed` 시그널을 주고받으며 동기적 폐쇄 처리.

---

## 3. 반응형 구현 전략 (Responsive Implementation)
단순한 비율(Scale) 조정이 아닌 **'지능형 레이아웃 전환'** 전략을 사용합니다.

### 📐 상세 반응형 규격 (Responsive Specs)
- **Breakpoint**: X축 768px (Mobile), Y축 500px (Compact/Landscape).
- **Minimap Slot**: 160px(PC) → **110px(Mobile/Compact)**. 시야 확보를 위해 가로/세로 폭과 여백을 최적화.
- **Chat Window Slot**: 260x150px(PC) → **200x110px(Mobile)**. 텍스트 시인성을 고려해 폰트 사이즈(12pt → 11pt) 동반 축소.
- **QuickAccess Slot**: 아이콘 44px(PC) → **36px(Mobile)**. 컴팩트 모드 시 바닥 마진(30px → 10px)을 줄여 게임 플레이 영역 확대.

### 🧩 슬롯 기반 재배치 (Slot-based Positioning)
- **PC**: 우측 상단 미니맵 아래에 사이드 메뉴 위치 (`MinimapUI.GetBottom()` API 연동).
- **Mobile**: `QuickAccess`와의 겹침을 방지하기 위해 사이드 메뉴를 **우측 하단 슬롯**으로 격리 배치 (`AnchorPoint(1, 1)` 기반).

---

## 4. 서버 부하 분석 (Server Load Analysis)
UI 시스템으로 인한 **서버 측 부하는 거의 0(Zero)**에 가깝습니다.

- **Client-Side Heavy**: 모든 레이아웃 계산, 애니메이션, 반응형 처리가 클라이언트 기기에서 수행됨.
- **Network Traffic**: 팝업 열기/닫기 등 단순 인터페이스 동작은 서버와 패킷을 주고받지 않음. 오직 실제 데이터 변동(아이템 사용, 강화 등)이 일어날 때만 **RemoteEvent**를 최소한으로 사용.

---

## 5. 비효율적인 소스 및 개선점 (Inefficiency & Improvements)

### ⚠️ 비효율적 로직 (Inefficiency)
- **MinimapController 스캔**: `RenderStepped` 루프 내에서의 태그 스캔 방식은 100인 이상의 대규모 전투 시 CPU 오버헤드 가능성이 있음 -> 정기적인 인터벌 폴링(Polling) 방식으로 전환 권장.
- **PopupLayout 인스턴스화**: 호출 시마다 인스턴스를 재생성하는 구조는 레이아웃 변경이 잦을 경우 메모리에 부담을 줄 수 있음 -> **객체 풀링(Object Pooling)** 도입 시 성능 향상 기대.

---

## 6. 전문가 제언 요청 (Suggestions for Review)
1. **Z-Index 관리 체계**: HUD 및 팝업 요소 간의 레이어 충돌 방지를 위한 '전역 Z-Index 위계표' 수립 의견.
2. **전역 UI 상태 관리**: 프로젝트 규모 확장에 따른 Redux/Rodux 스타일의 중앙 집중식 상태 관리 도입의 타당성 검토.

---
**작성자**: Antigravity (NewQuest AI Architect)🚩🚩🚩
