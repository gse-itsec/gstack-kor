# gstack-kor

> gstack 한국어 포크 — 모든 스킬 응답이 한국어로 제공됩니다.

[garrytan/gstack](https://github.com/garrytan/gstack) 기반의 한국어 커스텀 포크입니다.
원본의 auto-update, 텔레메트리, team mode 등 불필요한 기능을 제거하고,
모든 스킬 프롬프트에 한국어 응답 지시를 추가했습니다.

## 변경 사항 (원본 대비)

- 모든 스킬 프롬프트에 **한국어 응답 지시** 추가 (코드/명령어는 영어 유지)
- **Windows PowerShell 지원** (`setup.ps1`)
- auto-update, 텔레메트리, vendoring 경고, team mode 제거
- preamble 토큰 약 50k 절감

## 빠른 시작

### 필수 조건

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [Git](https://git-scm.com/)
- [Bun](https://bun.sh/) v1.0+
- [Node.js](https://nodejs.org/) (Windows 필수)

### 설치 (30초)

아무 디렉토리에서 clone한 뒤 setup을 실행하면 `~/.claude/skills/gstack`에 자동으로 연결됩니다.

**macOS / Linux / WSL (bash):**

```bash
git clone --single-branch --depth 1 https://github.com/gse-itsec/gstack-kor.git ~/gstack-kor
cd ~/gstack-kor && ./setup
```

**Windows (PowerShell):**

```powershell
git clone --single-branch --depth 1 https://github.com/gse-itsec/gstack-kor.git $HOME\gstack-kor
cd $HOME\gstack-kor
.\setup.ps1
```

### Claude Code에서 바로 설치

Claude Code를 열고 아래를 붙여넣으세요:

> gstack 설치: **`git clone --single-branch --depth 1 https://github.com/gse-itsec/gstack-kor.git ~/gstack-kor && cd ~/gstack-kor && ./setup`** 실행 후 CLAUDE.md에 "gstack" 섹션을 추가해서 모든 웹 브라우징에 /browse 스킬을 사용하고, mcp\_\_claude-in-chrome\_\_\* 도구는 절대 사용하지 말라고 명시하세요. 사용 가능한 스킬 목록: /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review, /design-consultation, /design-shotgun, /design-html, /review, /ship, /land-and-deploy, /canary, /benchmark, /browse, /connect-chrome, /qa, /qa-only, /design-review, /setup-browser-cookies, /setup-deploy, /retro, /investigate, /document-release, /codex, /cso, /autoplan, /plan-devex-review, /devex-review, /careful, /freeze, /guard, /unfreeze, /learn.

## 사용 예시

```
나:     일정 관리 앱을 만들고 싶어요.
나:     /office-hours
Claude: [구체적인 문제 상황을 질문합니다 — 가설이 아닌 실제 경험 기반]

나:     여러 구글 캘린더에 오래된 정보, 잘못된 장소...
        매번 준비하는 데 시간이 너무 오래 걸려요.

Claude: 프레이밍을 다시 짚어보겠습니다. "일정 브리핑 앱"이라고 하셨지만,
        실제로 설명하신 건 "개인 비서 AI"입니다.
        [미처 인식하지 못한 5가지 기능 추출]
        [4가지 전제에 대한 반론 — 동의/반대/조정]
        [3가지 구현 방안 + 노력 추정치]
        추천: 내일 가장 좁은 범위부터 출시하고, 실사용 데이터로
        학습하세요. 전체 비전은 3개월 프로젝트입니다.

나:     /plan-ceo-review
        [설계 문서를 읽고 범위를 검토, 10개 섹션 리뷰]

나:     /plan-eng-review
        [데이터 흐름 ASCII 다이어그램, 상태 머신, 에러 경로]

나:     계획 승인. Plan mode 종료.
        [11개 파일에 2,400줄 작성. 약 8분.]

나:     /review
        [자동 수정] 2건. [질문] 경쟁 조건 → 수정 승인.

나:     /qa https://staging.myapp.com
        [실제 브라우저에서 플로우 테스트, 버그 발견 및 수정]

나:     /ship
        테스트: 42 → 51 (+9개 추가). PR: github.com/you/app/pull/42
```

## 스프린트 프로세스

gstack은 도구 모음이 아닌 **프로세스**입니다. 스프린트 순서로 실행됩니다:

**구상 → 계획 → 구현 → 리뷰 → 테스트 → 배포 → 회고**

각 스킬이 다음 단계에 연결됩니다. `/office-hours`가 설계 문서를 작성하면 `/plan-ceo-review`가 읽고, `/plan-eng-review`가 테스트 계획을 작성하면 `/qa`가 이를 활용합니다.

## 스킬 목록

| 스킬 | 역할 | 설명 |
|------|------|------|
| `/office-hours` | **YC 오피스 아워** | 여기서 시작. 코드 작성 전 제품을 재구성하는 6가지 핵심 질문. |
| `/plan-ceo-review` | **CEO / 창업자** | 문제 재정의. 요청 안에 숨겨진 10점짜리 제품 발견. |
| `/plan-eng-review` | **엔지니어링 매니저** | 아키텍처, 데이터 흐름, 다이어그램, 엣지 케이스 확정. |
| `/plan-design-review` | **시니어 디자이너** | 디자인 차원별 0-10 평가, AI 슬롭 감지. |
| `/plan-devex-review` | **개발자 경험 리드** | DX 리뷰: 페르소나 탐색, TTHW 벤치마크, 마찰 포인트 추적. |
| `/design-consultation` | **디자인 파트너** | 디자인 시스템을 처음부터 구축. |
| `/review` | **스태프 엔지니어** | CI를 통과하지만 프로덕션에서 터지는 버그 발견. |
| `/investigate` | **디버거** | 체계적 근본 원인 디버깅. 조사 없이 수정 불가 원칙. |
| `/design-review` | **코딩하는 디자이너** | 디자인 감사 후 발견된 문제 직접 수정. |
| `/devex-review` | **DX 테스터** | 라이브 개발자 경험 감사. 실제 온보딩 테스트. |
| `/design-shotgun` | **디자인 탐색가** | 4-6개 AI 목업 변형 생성, 비교 보드에서 선택. |
| `/design-html` | **디자인 엔지니어** | 목업을 프로덕션 HTML로 변환. 30KB, 의존성 제로. |
| `/qa` | **QA 리드** | 앱 테스트, 버그 발견, 수정, 회귀 테스트 자동 생성. |
| `/qa-only` | **QA 리포터** | 코드 변경 없이 버그 리포트만 작성. |
| `/pair-agent` | **멀티 에이전트 코디네이터** | 브라우저를 다른 AI 에이전트와 공유. |
| `/cso` | **최고 보안 책임자** | OWASP Top 10 + STRIDE 위협 모델. |
| `/ship` | **릴리스 엔지니어** | main 동기화, 테스트, 커버리지 감사, PR 생성. |
| `/land-and-deploy` | **릴리스 엔지니어** | PR 머지, CI/배포 대기, 프로덕션 검증. |
| `/canary` | **SRE** | 배포 후 모니터링 루프. |
| `/benchmark` | **성능 엔지니어** | 페이지 로드 시간, Core Web Vitals, 리소스 크기 비교. |
| `/document-release` | **테크니컬 라이터** | 배포 후 모든 문서 자동 업데이트. |
| `/retro` | **엔지니어링 매니저** | 팀 기반 주간 회고. `/retro global`로 전체 프로젝트 통합. |
| `/browse` | **QA 엔지니어** | 실제 Chromium 브라우저. 클릭, 스크린샷. 명령당 ~100ms. |
| `/setup-browser-cookies` | **세션 매니저** | 실제 브라우저 쿠키를 헤드리스 세션으로 가져오기. |
| `/autoplan` | **리뷰 파이프라인** | CEO → 디자인 → 엔지니어링 리뷰 자동 실행. |
| `/learn` | **메모리** | 세션 간 학습 관리. 프로젝트별 패턴과 선호도 누적. |
| `/codex` | **세컨드 오피니언** | OpenAI Codex CLI를 통한 독립적 코드 리뷰. |
| `/careful` | **안전 가드레일** | 파괴적 명령 실행 전 경고. |
| `/freeze` | **편집 잠금** | 특정 디렉토리만 편집 허용. |
| `/guard` | **풀 세이프티** | `/careful` + `/freeze` 동시 적용. |
| `/unfreeze` | **잠금 해제** | `/freeze` 해제. |
| `/setup-deploy` | **배포 설정** | `/land-and-deploy`를 위한 일회성 설정. |

### 어떤 리뷰를 써야 할까?

| 대상 | 계획 단계 (코드 작성 전) | 라이브 감사 (배포 후) |
|------|--------------------------|----------------------|
| **최종 사용자** (UI, 웹앱) | `/plan-design-review` | `/design-review` |
| **개발자** (API, CLI, SDK) | `/plan-devex-review` | `/devex-review` |
| **아키텍처** (데이터 흐름, 성능) | `/plan-eng-review` | `/review` |
| **전부** | `/autoplan` | — |

## 트러블슈팅

**스킬이 안 보이나요?** `cd ~/.claude/skills/gstack && ./setup`

**`/browse` 실패?** `cd ~/.claude/skills/gstack && bun install && bun run build`

**짧은 명령어?** `./setup --no-prefix` — `/gstack-qa` 대신 `/qa` 사용.

**네임스페이스 명령어?** `./setup --prefix` — `/qa` 대신 `/gstack-qa` 사용.

**Windows 사용자:** Git Bash 또는 WSL에서 동작합니다. Bun의 Playwright 파이프 버그([bun#4253](https://github.com/oven-sh/bun/issues/4253)) 때문에 Node.js가 추가로 필요합니다. PowerShell에서는 `.\setup.ps1`을 사용하세요.

**Claude가 스킬을 못 찾나요?** 프로젝트의 `CLAUDE.md`에 아래 섹션을 추가하세요:

```
## gstack
모든 웹 브라우징에 /browse를 사용합니다. mcp__claude-in-chrome__* 도구는 사용하지 않습니다.
사용 가능한 스킬: /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review,
/design-consultation, /design-shotgun, /design-html, /review, /ship, /land-and-deploy,
/canary, /benchmark, /browse, /open-gstack-browser, /qa, /qa-only, /design-review,
/setup-browser-cookies, /setup-deploy, /retro, /investigate, /document-release, /codex,
/cso, /autoplan, /pair-agent, /careful, /freeze, /guard, /unfreeze, /learn.
```

## 제거

```bash
# 스킬 심링크 제거
find ~/.claude/skills -maxdepth 1 -type l 2>/dev/null | while read -r link; do
  case "$(readlink "$link" 2>/dev/null)" in gstack/*|*/gstack/*) rm -f "$link" ;; esac
done

# gstack 제거
rm -rf ~/.claude/skills/gstack

# 글로벌 상태 제거
rm -rf ~/.gstack
```

## 문서

| 문서 | 내용 |
|------|------|
| [스킬 상세](docs/skills.md) | 모든 스킬의 철학, 예제, 워크플로 |
| [빌더 철학](ETHOS.md) | Boil the Lake, Search Before Building |
| [아키텍처](ARCHITECTURE.md) | 설계 결정 및 시스템 내부 구조 |
| [브라우저 레퍼런스](BROWSER.md) | `/browse` 전체 명령어 참조 |
| [기여 가이드](CONTRIBUTING.md) | 개발 설정, 테스트, 기여자 모드 |
| [변경 이력](CHANGELOG.md) | 버전별 변경 사항 |

## 원본 프로젝트

[garrytan/gstack](https://github.com/garrytan/gstack) — MIT 라이선스

## 라이선스

MIT. 자유롭게 사용하세요.
