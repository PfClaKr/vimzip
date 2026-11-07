# vimzip

압축만 풀면 쓰는 리눅스 x86-64용 vim 개발 환경. 모든 바이너리가 정적 링크라 glibc 버전과 상관없이 동작합니다.

## 사용

```sh
unzip vimzip-linux-x86_64.zip && ./vimzip/install.sh
cd myproject && vim .
```

`vim .`은 파일 트리와 편집기를 열고, 그 폴더에서 마지막으로 열었던 파일을 복원합니다.

## 포함

- vim (musl 정적 빌드), ctags, fzf, shellcheck, ripgrep
- ALE, gutentags, tagbar, fzf.vim, nerdtree, gitgutter, fugitive, lightline, lightline-bufferline

## 키

| 키 | 기능 |
|---|---|
| `Ctrl+p` | 파일 검색 |
| `Ctrl+Shift+f` / `Space f` | 프로젝트 전체 검색 |
| `Space b` / `Space t` | 열린 파일 / 심볼 검색 |
| `Tab` / `Shift+Tab` / `Space q` | 다음 / 이전 / 닫기 (위쪽 탭) |
| `F2` / `F3` / `F4` | 파일 트리 / 함수 목록 / 터미널 |
| `F12`, `gd` / `Ctrl+t` | 정의로 이동 / 돌아오기 |
| `]e` / `[e` | 다음 / 이전 에러 |
| `gcc` | 주석 토글 |
| `Ctrl+s` | 저장 |
| `F5` `F9` `F10` `F11` | 디버그 시작·계속 / 중단점 / 다음 줄 / 함수 안으로 (gdb 필요) |

- 복사(`y`)한 내용은 SSH 너머 로컬 클립보드로도 갑니다 (OSC 52 지원 터미널).
- 전체 바꾸기: 검색 결과에서 `Alt+a` → `Enter` 후 `:cdo s/old/new/g | update`
- `Ctrl+Shift+f`는 터미널이 가로채면 동작하지 않습니다. 그때는 `Space f`를 쓰세요.
- 서버에 clangd가 있으면 정의 이동·에러 표시에 clangd를 씁니다.

## 빌드

```sh
git clone --recursive https://github.com/PfClaKr/vimzip && cd vimzip
./build.sh                # Alpine
CC=musl-gcc ./build.sh    # 그 외 (musl-tools 필요)
```

버전은 `versions.env`. 매주 자동으로 갱신 PR이 열립니다.
