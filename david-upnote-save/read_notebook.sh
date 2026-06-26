#!/bin/bash
# UpNote 로컬 SQLite DB에서 특정 노트북의 노트를 읽어온다.
# 사용법: ./read_notebook.sh "노트북이름"
# 출력: 각 노트를 "=== 제목 ===" + 본문 형태로 출력 (구분자: \x1f)

NOTEBOOK="${1:-유튜브}"
DB="$HOME/Library/Containers/com.getupnote.desktop/Data/Library/Application Support/UpNote/upnote.sqlite3"

if [ ! -f "$DB" ]; then
  echo "ERROR: UpNote DB를 찾을 수 없습니다. 데스크톱 앱 설치/동기화 확인 필요." >&2
  exit 1
fi

# WAL 모드 DB를 안전하게 읽기 위해 읽기 전용 + immutable 모드 사용하지 않고 직접 쿼리
sqlite3 "$DB" <<SQL
.mode list
.separator "|"
SELECT n.id, n.title, n.text
FROM notes n
JOIN organizers o ON o.noteId = n.id
JOIN notebooks nb ON nb.id = o.notebookId
WHERE nb.title = '${NOTEBOOK}'
  AND o.deleted = 0 AND n.trashed = 0 AND n.deleted = 0
ORDER BY n.createdAt DESC;
SQL
