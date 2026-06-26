---
name: david-upnote-save
description: >
  현재 대화 내용을 한국어로 요약해서 UpNote에 노트로 저장하는 스킬.
  사용자가 "업노트에 저장해줘", "업노트에 올려줘", "upnote에 저장", "upnote save" 등의
  말을 하면 반드시 이 스킬을 사용할 것.
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

## 작성 가이드라인

- **언어**: 한국어로 작성 (코드·고유명사는 원어 유지)
- **간결함**: 핵심만 추출, 장황하게 모든 대화를 옮기지 않는다
- **실용성**: 나중에 다시 읽을 때 바로 이해할 수 있도록 맥락을 충분히 담는다
