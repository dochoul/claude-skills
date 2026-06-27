---
name: david-llm-wiki
description: >
  카파시의 LLM-Wiki 개념을 구현한 개인 지식 위키 스킬. 노션 "나의 링크"에 쌓인 링크
  (유튜브·웹·소셜 등)를 분석해 (1) 맥 로컬 마크다운 위키에 저장·연결하고 (2) 노션 "지식 서재"에
  읽기용 사본으로 미러링한다. 또한 위키에 질문(query)하거나 위키를 점검(lint)할 수 있다.
  사용자가 "노션 업데이트", "위키 업데이트", "지식 서재 정리해줘", "링크 정리해줘",
  링크를 주며 "이거 분석해줘"라고 하면 → 수집(ingest) 워크플로우 실행.
  "위키에서 ~ 찾아줘/물어봐", "내가 ~에 대해 뭐 모았지?"라고 하면 → 질문(query).
  "위키 점검해줘", "지식 서재 정리/건강검진"이라고 하면 → 점검(lint).
  단순 제목·링크가 아니라 내용에 담긴 깊이 있는 내용을 정리·연결하는 것이 목적이다.
---

# David의 LLM-Wiki 스킬

카파시의 LLM-Wiki 패턴을 구현한 개인 지식 위키. 사람은 소스 큐레이션과 좋은 질문을,
LLM은 분석·정리·연결·기록(bookkeeping)을 맡는다.

## 하이브리드 구조

```
📥 입력:    노션 "나의 링크" DB (아이패드 공유로 쌓임)
🧠 위키(원본): 맥 로컬 마크다운 = WIKI_DIR (LLM이 연결·정리하는 main)
📤 열람(사본): 노션 "지식 서재" 페이지 (어디서든 읽기용)
```

- **로컬 위키가 원본(main), 노션은 읽기용 사본.** 수정·연결은 항상 로컬에서.
- 인증/경로: `~/.claude/skills/david-llm-wiki/.env` (gitignore됨). 매 작업 전 로드:
  `set -a; source ~/.claude/skills/david-llm-wiki/.env; set +a`
  - `NOTION_TOKEN`, `NOTION_MYLINKS_DB`(나의 링크), `NOTION_LIBRARY_PAGE`(노션 지식서재), `WIKI_DIR`(로컬 위키 폴더)
- Notion-Version 헤더: `2022-06-28`
- 로컬 위키 구조·규칙: `$WIKI_DIR/CLAUDE.md` (3계층: `raw/`=원본, `문서/`+`허브/`=가공, `CLAUDE.md`=스키마, `index.md`=색인, `log.md`=수집로그)
- 위키링크는 옵시디언 형식 `[[파일명]]` / `[[파일명|표시명]]` (확장자 .md 제외)
- 실행 시 중간 확인 없이 끝까지 처리한다.

---

## A. 수집(Ingest) — "노션/위키 업데이트", "이거 분석해줘"

### 1. 링크 확보
- "나의 링크" DB 조회. 링크 0개면 종료. 각 행 URL(Name 또는 URL)·행 id 수집.
  ```bash
  curl -s -X POST "https://api.notion.com/v1/databases/$NOTION_MYLINKS_DB/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" -d '{"sorts":[{"timestamp":"created_time","direction":"descending"}]}'
  ```
- 링크를 직접 준 경우엔 그것만 처리.

### 2. 종류별 내용 확보
- **🎬 유튜브**: scratchpad에서 yt-dlp 자막.
  `yt-dlp --skip-download --print "%(title)s :: %(uploader)s :: %(duration_string)s :: live=%(live_status)s" URL`
  `yt-dlp --skip-download --write-auto-subs --sub-langs ko --sub-format vtt --convert-subs srt -o sub URL`
  (ko 없으면 en). VTT를 평문(타임스탬프·중복 제거)으로 정리해 전문 읽기. 음악/MV는 가용정보.
- **📰 웹페이지**: WebFetch로 본문. 막히면 `curl -sL URL`.
- **소셜(X·페북·인스타)**: 본문이 노션 Name에 있으면 그걸 사용. 로그인 필요한 본문은 (수동 실행 시) Claude in Chrome으로 시도. 영상은 캡션까지만.
- **⏸️ 라이브/자막없음/본문불가**: 심층분석 대신 간단기록. 제목 앞 `[분석보류]`, 한계 명시.

### 3. 심층 분석 (단순요약 금지)
핵심 한 줄 / 섹션별 논지·근거 / 수치·디테일 / 비교·포지셔닝 / 실무 시사점 /
비판적 시각(협찬·광고·과장·편향) / 총평.

### 4a. 원본 저장 (raw — 불변, source of truth)
확보한 **자막 전문/웹 본문 원문**을 `$WIKI_DIR/raw/<다duned제목>.md`에 그대로 저장한다.
- 맨 위에 출처 URL·수집일 헤더, 그 아래 원문 전체. **절대 수정/삭제하지 않는다.**
- raw가 없는 경우(소셜 본문 불가·라이브 등)는 생략하고 문서에 한계를 명시.

### 4b. 분석 저장 (wiki)
`$WIKI_DIR/문서/<다듬은제목>.md` 작성. 특수문자(\/:*?"<>|) 제거.
- 프론트매터 `notion_id`(미러 후 채움)·`title`·`raw: raw/<파일>`(있으면), 본문 `# 제목` + 맨 위 원본 링크·출처 + 분석.
- 본문에서 원본을 `[[raw/제목]]`로 링크해 출처를 가리킨다.

### 5. 연결 (위키의 핵심)
- `$WIKI_DIR/허브/`에서 관련 허브를 찾는다. 없으면 새 허브 생성(`# 허브명` + 설명 + "## 포함 문서").
- 새 문서 하단에 `🔗 **허브**: [[허브명]] · ...` 추가.
- 해당 허브의 "포함 문서"에 `- [[문서stem|제목]]` 추가.
- 직접 관련된 다른 문서와도 `[[ ]]`로 상호링크.
- `$WIKI_DIR/index.md`의 문서(필요시 허브) 목록 갱신.

### 6. 노션 미러 (읽기용 사본)
`NOTION_LIBRARY_PAGE` 자식으로 새 페이지 생성. callout(핵심 한 줄)·heading_2·bulleted_list_item·quote·divider·총평. icon은 종류 이모지. 블록 많으면 python3 urllib.
- 생성된 page id를 로컬 문서 프론트매터 `notion_id`에 기록.

### 6b. 수집 로그 기록
`$WIKI_DIR/log.md` 표 맨 아래에 한 줄 append:
`| <날짜> | <제목> | <종류> | <raw ✅/—> | <허브> | <출처URL> |`. (날짜는 args/환경에서 받은 실제 날짜 사용)

### 7. 원본 링크 삭제
"나의 링크"의 처리한 행 archive.
```bash
curl -s -X PATCH "https://api.notion.com/v1/pages/<행id>" \
  -H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" -d '{"archived": true}'
```

### 8. 완료 알림
생성 문서 제목·연결 허브·노션 URL·삭제 링크 수 보고.

---

## B. 질문(Query) — "위키에서 ~ 찾아줘", "내가 ~에 대해 뭐 모았지?"

1. `$WIKI_DIR/index.md`와 `허브/`를 먼저 훑어 관련 주제 위치 파악.
2. `grep -rl "키워드" "$WIKI_DIR/문서"`로 관련 문서를 찾아 읽는다.
3. 여러 문서를 **종합**해 답하고, 근거가 된 문서를 `[[ ]]`로 인용한다.
4. 답이 가치 있으면(반복될 질문이면) 새 종합 문서로 위키에 남기는 것을 고려.

## C. 점검(Lint) — "위키 점검해줘", "건강검진"

`$WIKI_DIR` 전체를 훑어 다음을 점검·보수:
- 어느 허브에도 안 묶인 **고아 문서** → 허브 연결
- **끊긴 위키링크**(대상 파일 없는 `[[ ]]`)
- 내용이 **모순**되거나 **오래된** 주장
- 거의 빈 허브 / 너무 커진 허브(분할 검토)
- `index.md`와 실제 파일 목록 불일치
발견 사항과 조치를 보고한다.

## 작성 가이드라인
- 언어: 한국어 (고유명사·코드 원어 유지)
- 깊이 우선, 협찬·편향은 반드시 명시, 못 가져온 내용은 한계 명시
- 로컬 위키가 원본 · 노션은 읽기용 사본
- `.env`는 절대 커밋/노출 금지 (`.gitignore` 차단)
