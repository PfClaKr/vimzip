# vimzip

압축만 풀면 쓰는 리눅스 x86-64용 vim 개발 환경. 모든 바이너리가 정적 링크라 glibc 버전과 상관없이 동작합니다.

## 사용

```sh
unzip vimzip-linux-x86_64.zip
alias vim=~/vimzip/vim
```

## 포함

- vim (musl 정적 빌드), ctags, fzf, shellcheck, ripgrep
- ALE, gutentags, tagbar, fzf.vim, nerdtree, gitgutter, fugitive, commentary, lightline

| 키 | 기능 |
|---|---|
| `Ctrl+p` | 파일 검색 |
| `Space b` / `Space t` / `Space f` | 버퍼 / 태그 / 전체 텍스트 검색 |
| `F2` / `F3` | 파일 트리 / 함수 목록 |
| `Ctrl+]` / `Ctrl+t` | 정의로 이동 / 돌아오기 |
| `]e` / `[e` | 다음 / 이전 에러 |
| `gcc` | 주석 토글 |

## 빌드

```sh
git clone --recursive https://github.com/PfClaKr/vimzip && cd vimzip
./build.sh                # Alpine
CC=musl-gcc ./build.sh    # 그 외 (musl-tools 필요)
```

버전은 `versions.env`. 매주 자동으로 갱신 PR이 열립니다.
