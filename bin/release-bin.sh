#!/bin/sh

set -eu

REPOSITORY="paulvkey/openclaw-scripts"
TARGET_BRANCH="main"
BIN_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

usage() {
  printf '%s\n' "用法：$0 <release-tag>"
  printf '%s\n' "示例：$0 v0.2.0"
}

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
  -*)
    printf '%s\n' "错误：release tag 不能以 '-' 开头。" >&2
    exit 2
    ;;
esac

RELEASE_TAG=$1

if ! command -v gh >/dev/null 2>&1; then
  printf '%s\n' '错误：未找到 gh，请先安装 GitHub CLI。' >&2
  exit 1
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  printf '%s\n' '错误：GitHub CLI 尚未登录或凭证已失效，请先运行 gh auth login。' >&2
  exit 1
fi

if gh release view "$RELEASE_TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
  printf '%s\n' "错误：release ${RELEASE_TAG} 已存在，请使用新的 tag。" >&2
  exit 1
fi

set --
ASSET_COUNT=0

for ASSET_PATH in "$BIN_DIR"/*; do
  [ -f "$ASSET_PATH" ] || continue
  [ ! -L "$ASSET_PATH" ] || continue

  ASSET_NAME=${ASSET_PATH##*/}
  case "$ASSET_NAME" in
    *.sh)
      continue
      ;;
    *'#'*)
      printf '%s\n' "错误：附件文件名不能包含 '#'：${ASSET_NAME}" >&2
      exit 1
      ;;
  esac

  if [ ! -r "$ASSET_PATH" ] || [ ! -s "$ASSET_PATH" ]; then
    printf '%s\n' "错误：附件不可读或内容为空：${ASSET_NAME}" >&2
    exit 1
  fi

  set -- "$@" "$ASSET_PATH"
  ASSET_COUNT=$((ASSET_COUNT + 1))
done

if [ "$ASSET_COUNT" -eq 0 ]; then
  printf '%s\n' "错误：${BIN_DIR} 中没有可发布的附件。" >&2
  exit 1
fi

printf '%s\n' "即将创建 release ${RELEASE_TAG}，上传以下 ${ASSET_COUNT} 个附件："
RELEASE_NOTES='包含以下安装附件：'
for ASSET_PATH in "$@"; do
  ASSET_NAME=${ASSET_PATH##*/}
  printf '  - %s\n' "$ASSET_NAME"
  RELEASE_NOTES="${RELEASE_NOTES}
- ${ASSET_NAME}"
done

if ! gh release create "$RELEASE_TAG" "$@" \
  --repo "$REPOSITORY" \
  --target "$TARGET_BRANCH" \
  --title "macOS 依赖安装包 (${RELEASE_TAG})" \
  --notes "$RELEASE_NOTES" \
  --generate-notes \
  --draft
then
  printf '%s\n' '错误：创建或上传失败；GitHub 上可能保留了未完成的草稿 release，请检查后重试。' >&2
  exit 1
fi

if ! gh release edit "$RELEASE_TAG" \
  --repo "$REPOSITORY" \
  --draft=false \
  --latest
then
  printf '%s\n' "错误：附件已上传，但发布失败；release ${RELEASE_TAG} 仍保留为草稿。" >&2
  exit 1
fi

printf '%s\n' "release ${RELEASE_TAG} 创建完成，并已设为 Latest。"
