---
name: david-upnote-save
description: >
  현재 대화 내용을 한국어로 요약해서 UpNote에 노트로 저장하는 스킬.
  사용자가 "업노트에 저장해줘", "업노트에 올려줘", "upnote에 저장", "upnote save" 등의
  말을 하면 반드시 이 스킬을 사용할 것.
  또한 "업노트 업데이트"라고 하면 Google Drive의 .txt 유튜브 링크를 읽어
  요약한 뒤 UpNote에 노트로 저장하는 워크플로우를 실행할 것.
  "업노트에서 유튜브 읽어줘", "업노트 유튜브 정리해줘"라고 하면 UpNote 로컬 DB에서
  유튜브 노트북의 링크를 직접 읽어 요약하고 다시 저장하는 워크플로우를 실행할 것.
  대화를 마무리하면서 UpNote에 기록하고 싶다는 뉘앙스가 있으면 적극적으로 이 스킬을 활용할 것.
---

# UpNote Save 스킬

## 목적

현재 Claude와 나눈 대화를 요약하여 UpNote에 마크다운 노트로 저장한다.
x-callback-url을 통해 UpNote 앱에 직접 노트를 생성한다.

## 실행 단계

### 1. 주제 파악

대화 전체를 훑어보고 핵심 주제를 2~4개 단어로 요약한다. (한국어)

### 2. 노트 내용 작성

아래 형식으로 마크다운 내용을 작성한다:

```markdown
## 요약

(대화 전체를 3~5문장으로 핵심만 요약.)

## 주요 내용

(소제목별로 정리. 불릿 포인트 활용.)

## 참고 / 메모

(코드, 링크, 추가 메모 등. 없으면 생략.)
```

### 3. UpNote에 저장

아래 Bash 명령으로 UpNote에 노트를 생성한다:

```bash
open "upnote://x-callback-url/note/new?title=TITLE&text=CONTENT&markdown=true"
```

- `TITLE`: URL 인코딩된 노트 제목 (날짜 + 주제, 예: `2026-06-26 Claude와 옵시디언 연동`)
- `CONTENT`: URL 인코딩된 마크다운 본문
- URL 인코딩은 Python으로 처리:

```bash
python3 -c "import urllib.parse; print(urllib.parse.quote('내용'))"
```

### 4. 완료 알림

저장이 완료되면 제목과 요약 내용을 알린다.

## "업노트 업데이트" 워크플로우 (유튜브 링크 정리)

사용자가 **"업노트 업데이트"** 라고 하면 아래를 실행한다:

### 1. Google Drive에서 .txt 링크 읽기

아래 폴더에서 `.txt` 파일을 찾는다:

```
~/Library/CloudStorage/GoogleDrive-dochoul@gmail.com/내 드라이브/Obsidian/
```

`.txt` 파일에서 유튜브 링크(`youtube.com/watch` 또는 `youtu.be`)를 추출한다.

### 2. 영상 정보 가져오기 + 요약

각 링크마다 `yt-dlp`로 제목·설명·채널을 가져온다:

```bash
yt-dlp --skip-download --print "%(title)s\n%(uploader)s\n%(description)s" "URL"
```

가져온 정보를 바탕으로 핵심 요약을 작성한다.

### 3. UpNote에 노트로 저장

각 영상마다 x-callback-url로 노트를 생성하되, **"유튜브" 노트북**에 저장한다.
제목은 영상 제목, 본문은 링크 + 요약 + 채널 정보를 포함한다.

```bash
open "upnote://x-callback-url/note/new?title=TITLE&text=CONTENT&notebook=유튜브&markdown=true"
```

- `notebook` 파라미터에 노트북 이름(`유튜브`)을 넣으면 해당 노트북에 저장된다.
- `notebook` 값도 URL 인코딩한다.

### 4. .txt 파일 삭제

처리 완료한 `.txt` 파일은 삭제한다 (시스템 휴지통으로 이동).

### 5. 완료 알림

저장한 영상 제목 목록을 알린다.

## "업노트에서 유튜브 읽어줘" 워크플로우 (UpNote 직접 읽기)

UpNote는 공식 읽기 API가 없지만, 로컬 SQLite DB를 직접 읽으면 노트 내용을 가져올 수 있다.
사용자가 **"업노트에서 유튜브 읽어줘"**, **"업노트 유튜브 정리해줘"** 라고 하면 아래를 실행한다.

> ⚠️ 비공식 방식. UpNote **데스크톱 앱이 이 Mac에 설치+동기화**돼 있어야 한다.
> 앱 업데이트로 DB 구조가 바뀌면 깨질 수 있다.

### DB 구조 (참고)

- DB: `~/Library/Containers/com.getupnote.desktop/Data/Library/Application Support/UpNote/upnote.sqlite3`
- `notes` 테이블: `id`, `title`, `text` (본문), `trashed`, `deleted`
- `notebooks` 테이블: `id`, `title`
- `organizers` 테이블: `noteId` ↔ `notebookId` 연결 (노트북 소속 정보)

### 1. 유튜브 노트북에서 노트 읽기

함께 제공된 헬퍼 스크립트를 사용한다:

```bash
~/.claude/skills/david-upnote-save/read_notebook.sh "유튜브"
```

출력: `노트id|제목|본문` 형식. 각 노트 본문에서 유튜브 링크를 추출한다.

### 2. 새 링크만 처리

본문에 이미 "## 요약"이 들어있는 노트는 이미 처리된 것으로 보고 건너뛴다.
요약이 없는, 링크만 있는 노트를 대상으로 삼는다.

### 3. 영상 정보 + 요약

`yt-dlp`로 제목·설명을 가져와 요약한다 ("업노트 업데이트" 워크플로우와 동일).

### 4. UpNote에 요약 저장

요약 결과를 "유튜브" 노트북에 새 노트로 저장한다 (x-callback-url, `notebook=유튜브`).

### 5. 원본 링크 노트 휴지통 이동

요약을 만든 뒤, 본문이 링크뿐인 원본 노트는 더 이상 필요 없으므로 휴지통으로 보낸다.

```bash
DB="$HOME/Library/Containers/com.getupnote.desktop/Data/Library/Application Support/UpNote/upnote.sqlite3"
# 안전을 위해 먼저 백업
cp "$DB" /tmp/upnote_backup.sqlite3
NOW=$(python3 -c "import time;print(int(time.time()*1000))")
sqlite3 "$DB" "UPDATE notes SET trashed=1, synced=0, updatedAt=${NOW} WHERE id='노트id';"
```

- **하드 삭제 금지** — `trashed=1`로 휴지통 이동만 (복구 가능).
- 작업 전 DB를 반드시 백업한다.
- ⚠️ **UpNote 앱을 껐다 켜야 화면에 반영된다** (앱은 메모리의 노트를 보여주므로 외부 DB 수정이 즉시 안 보임). 사용자에게 재시작을 안내할 것.

### 6. 완료 알림

읽어온 링크 수, 저장한 요약 목록, 휴지통으로 보낸 노트 수를 알리고
"UpNote를 껐다 켜면 정리됩니다"라고 안내한다.

## 작성 가이드라인

- **언어**: 한국어로 작성 (코드·고유명사는 원어 유지)
- **간결함**: 핵심만 추출, 장황하게 모든 대화를 옮기지 않는다
- **실용성**: 나중에 다시 읽을 때 바로 이해할 수 있도록 맥락을 충분히 담는다
