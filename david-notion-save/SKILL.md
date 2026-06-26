---
name: david-notion-save
description: >
  노션(Notion)의 "나의 링크" DB에 쌓인 유튜브 링크를 읽어, 영상 자막을 기반으로
  깊이 있게 분석한 뒤 "유튜브 서재" 페이지에 문서 한 편으로 정리하는 스킬.
  사용자가 "노션 정리해줘", "유튜브 서재 정리해줘", "노션 유튜브 정리", "영상 분석해줘",
  또는 유튜브 URL을 주며 "이 영상 분석해줘"라고 하면 반드시 이 스킬을 사용할 것.
  단순 제목·링크가 아니라 영상 내용 안에 담긴 깊이 있는 내용을 정리하는 것이 목적이다.
---

# Notion 유튜브 서재 스킬

## 목적

유튜브 영상을 **자막(transcript) 기반으로 깊이 있게 분석**해서 노션에 **문서 한 편**으로 정리한다.
제목·링크 같은 표면 정보가 아니라, 영상이 실제로 담고 있는 논지·핵심 주장·근거·인사이트를 추출한다.

## 노션 구조

```
📚 유튜브 서재 (페이지)   ← 분석 문서들이 모이는 곳
📋 나의 링크 (DB)        ← 아이패드 유튜브 공유가 자동으로 쌓이는 입력함
```

- 인증 정보는 `~/.claude/skills/david-notion-save/.env`에 있다 (gitignore 처리, GitHub 미포함).
  - `NOTION_TOKEN`, `NOTION_MYLINKS_DB`(나의 링크), `NOTION_LIBRARY_PAGE`(유튜브 서재)
- API 호출 전 항상 `set -a; source ~/.claude/skills/david-notion-save/.env; set +a`로 환경변수를 로드한다.
- Notion-Version 헤더는 `2022-06-28` 사용.

## 실행 단계

### 1. 분석할 링크 확보

- **"노션 정리해줘"류**: "나의 링크" DB를 조회해 유튜브 링크를 모두 가져온다.
  ```bash
  curl -s -X POST "https://api.notion.com/v1/databases/$NOTION_MYLINKS_DB/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" -d '{"sorts":[{"timestamp":"created_time","direction":"descending"}]}'
  ```
  링크는 `Name`(title) 또는 `URL` 속성에 들어있다. 행의 `id`도 기록(나중에 삭제용).
- **URL을 직접 준 경우**: 그 URL 하나만 처리.

### 2. 자막 추출

```bash
cd <scratchpad>
yt-dlp --skip-download --print "%(title)s :: %(uploader)s :: %(duration_string)s" "URL"
yt-dlp --skip-download --write-auto-subs --sub-langs "ko" --sub-format vtt --convert-subs srt -o "sub" "URL"
```
- 한국어 자막이 없으면 `--sub-langs "en"` 등으로 시도.
- VTT를 평문으로 정리(타임스탬프·중복 태그 제거)한 뒤 전문을 읽는다.
- **자막이 없는 영상(음악·MV 등)**: 심층 분석 대신 제목·설명·수록곡 등 가용 정보로 정리한다.

### 3. 심층 분석 작성

자막 전문을 읽고 아래를 추출한다 (단순 요약 금지, 깊이 우선):
- 핵심 한 줄 메시지
- 섹션별 주요 내용·논지·근거
- 기술/디테일 수치
- 다른 것과의 비교·포지셔닝
- 실무 활용/시사점
- 비판적 시각 (협찬·광고성, 과장, 편향 등이 있으면 반드시 짚는다)
- 총평

### 4. 유튜브 서재에 문서 생성

`NOTION_LIBRARY_PAGE`를 부모로 하는 새 페이지를 만든다. 본문은 Notion 블록으로 구성:
- 맨 위: 영상 링크(`link` 포함 paragraph), 채널·길이
- `callout`(핵심 한 줄), `heading_2`(섹션), `bulleted_list_item`, `divider`, 총평 `paragraph`
- 페이지 `icon`은 주제에 맞는 이모지, `title`은 깔끔히 다듬은 영상 제목

```bash
curl -s -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" -d '{"parent":{"type":"page_id","page_id":"'$NOTION_LIBRARY_PAGE'"}, "icon":{"emoji":"🤖"}, "properties":{"title":[...]}, "children":[...]}'
```
(블록이 많으면 Python `urllib`로 작성하는 편이 안전하다.)

### 5. 처리한 링크 삭제

문서를 만든 뒤 "나의 링크"의 해당 행을 archive(삭제)한다. 노션은 동기화 충돌 없이 삭제된다.
```bash
curl -s -X PATCH "https://api.notion.com/v1/pages/<행id>" \
  -H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" -d '{"archived": true}'
```

### 6. 완료 알림

생성한 문서 제목과 노션 URL, 삭제한 링크 수를 알린다.

## 작성 가이드라인

- **언어**: 한국어 (고유명사·코드는 원어 유지)
- **깊이 우선**: 표면 정보가 아니라 영상이 담은 실제 내용·인사이트를 정리
- **정직함**: 협찬·광고성 콘텐츠는 반드시 그 사실을 명시
- **문서 형식**: 표(DB)가 아니라 읽기 좋은 한 편의 문서로 구성
- **토큰 비밀 유지**: `.env`는 절대 커밋하지 않는다 (`.gitignore`로 차단됨)
