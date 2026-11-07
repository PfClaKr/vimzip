# vimzip

압축만 풀면 쓰는 리눅스 x86-64용 vim 개발 환경. 모든 바이너리가 정적 링크라 glibc 버전과 상관없이 동작합니다.

![vim .](docs/layout.png)

## 사용

```sh
unzip vimzip-linux-x86_64.zip && ./vimzip/install.sh
cd myproject && vim .
```

`vim .`은 파일 트리와 편집기를 열고, 그 폴더에서 마지막으로 열었던 파일을 복원합니다. 파일은 자동 저장됩니다 (편집 모드를 나갈 때, 수정 직후, 다른 파일·창으로 옮길 때).

## 포함

- vim (musl 정적 빌드), ctags, fzf, shellcheck, ripgrep
- ALE, gutentags, tagbar, fzf.vim, nerdtree, gitgutter, fugitive, lightline, lightline-bufferline

## 단축키

`Space`가 리더 키입니다. `Ctrl+w`로 시작하는 키는 터미널 안에서도 동작합니다.

### 파일과 검색

| 키 | 기능 |
|---|---|
| `Ctrl+p` | 파일 이름 검색 |
| `Ctrl+Shift+f` / `Space f` | 프로젝트 전체 텍스트 검색 |
| `Space b` | 열린 파일 검색 |
| `Space t` | 심볼(함수, 구조체) 검색 |
| 검색 창에서 `Enter` / `Ctrl+v` / `Ctrl+x` | 열기 / 세로 분할로 열기 / 가로 분할로 열기 |
| `/단어` → `n` / `N` | 현재 파일에서 찾기 → 다음 / 이전 |
| `*` | 커서 아래 단어 찾기 |
| `:%s/old/new/g` | 현재 파일에서 바꾸기 |
| 전체 검색에서 `Alt+a` → `Enter` → `:cdo s/old/new/g` | 프로젝트 전체에서 바꾸기 |

### 탭 (열린 파일)

| 키 | 기능 |
|---|---|
| `Tab` / `Shift+Tab` | 다음 / 이전 파일 |
| `Space q` | 현재 파일 닫기 |
| `Ctrl+s` | 저장 (자동 저장도 켜져 있음) |

### 창 분할

| 키 | 기능 |
|---|---|
| `Space v` / `Space s` | 세로 / 가로 분할 |
| `Ctrl+h` `Ctrl+j` `Ctrl+k` `Ctrl+l` | 왼쪽 / 아래 / 위 / 오른쪽 창으로 이동 |
| `Ctrl+w h` `j` `k` `l` | 창 이동 (터미널 안에서도) |
| `Ctrl+w =` | 창 크기 균등하게 |
| `Ctrl+w _` / `Ctrl+w \|` | 현재 창 높이 / 너비 최대로 |
| `Ctrl+w +` `-` `<` `>` | 높이 / 너비 조절 (마우스로 경계선을 끌어도 됨) |
| `Ctrl+w x` | 옆 창과 위치 바꾸기 |
| `Ctrl+w H` `J` `K` `L` | 창을 맨 왼쪽 / 아래 / 위 / 오른쪽으로 옮기기 |
| `Ctrl+w q` | 창 닫기 |

### 터미널

| 키 | 기능 |
|---|---|
| `F4` | 아래 터미널 패널 열기 / 숨기기 (숨겨도 계속 실행) |
| `Space -` / `Space \` | 현재 창 아래 / 오른쪽에 새 터미널 |
| 터미널에서 `Ctrl+w n` / `Ctrl+w \` | 아래 / 오른쪽에 터미널 하나 더 |
| 터미널에서 `Ctrl+w N` → `i` | 스크롤·복사 모드 → 다시 입력 (마우스 휠도 가능) |
| 터미널에서 `Ctrl+w :` | vim 명령 입력 |
| `exit` | 터미널 닫기 |

![splits](docs/splits.png)

### 코드 탐색

| 키 | 기능 |
|---|---|
| `F12` / `gd` | 정의로 이동 |
| `Ctrl+t` / `Ctrl+o` | 이동 전 위치로 돌아오기 |
| `gr` / `K` | 참조 찾기 / 설명 보기 (clangd 있을 때) |
| `]e` / `[e` | 다음 / 이전 에러 |
| `Space e` | 현재 줄 에러 자세히 |
| `%` | 짝 괄호로 이동 |
| `F3` | 함수 목록 (`Enter`로 이동) |

### 파일 트리 (`F2`)

| 키 | 기능 |
|---|---|
| `Enter` / `s` / `i` | 열기 / 세로 분할로 열기 / 가로 분할로 열기 |
| `m` | 파일 추가·이름 변경·삭제 메뉴 |
| `I` / `R` | 숨김 파일 표시 / 새로고침 |
| `C` / `u` | 선택한 폴더를 루트로 / 상위 폴더로 |

### 편집

| 키 | 기능 |
|---|---|
| `u` / `Ctrl+r` | 실행 취소 / 다시 실행 (껐다 켜도 유지) |
| `gcc` / 선택 후 `gc` | 줄 / 선택 영역 주석 토글 |
| `yy` / `dd` / `p` | 줄 복사 / 잘라내기 / 붙여넣기 |
| `y` / 선택 후 `Ctrl+c` | 복사 (SSH 너머 로컬 클립보드로도, OSC 52 지원 터미널) |
| `>>` / `<<` | 들여쓰기 / 내어쓰기 |
| `=` | 선택 영역 자동 정렬 (`gg=G`는 파일 전체) |
| `Ctrl+n` | 단어 자동완성 (자동 팝업은 꺼져 있음) |

### Git

| 키 | 기능 |
|---|---|
| `]c` / `[c` | 다음 / 이전 변경 위치 |
| `Space hp` / `Space hs` / `Space hu` | 변경 미리보기 / 스테이지 / 되돌리기 |
| `:Git` | 상태 창 (`s` 스테이지, `u` 취소, `=` diff, `cc` 커밋) |
| `:Git blame` / `:Gdiffsplit` | 줄별 작성자 / 변경 비교 |

### 디버그 (gdb 필요)

| 키 | 기능 |
|---|---|
| `F5` | 시작 (`./a.out 인자` 입력) / 계속 |
| `F9` | 중단점 토글 |
| `F10` / `F11` / `Shift+F11` | 다음 줄 / 함수 안으로 / 함수 밖으로 |

- `Ctrl+Shift+f`는 터미널이 가로채면 동작하지 않습니다. 그때는 `Space f`를 쓰세요.
- 서버에 clangd가 있으면 정의 이동·에러 표시에 clangd를 씁니다.

## 스크린샷

| 전체 검색 | 파일 검색 |
|---|---|
| ![search](docs/search.png) | ![files](docs/files.png) |
| **함수 목록 + 터미널** | **디버그** |
| ![panels](docs/panels.png) | ![debug](docs/debug.png) |

## 빌드

```sh
git clone --recursive https://github.com/PfClaKr/vimzip && cd vimzip
./build.sh                # Alpine
CC=musl-gcc ./build.sh    # 그 외 (musl-tools 필요)
```

버전은 `versions.env`. 매주 자동으로 갱신 PR이 열립니다.
