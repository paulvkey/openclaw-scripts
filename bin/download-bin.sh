#!/bin/sh

set -eu

REPOSITORY="paulvkey/openclaw-scripts"
BIN_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
API_URL="https://api.github.com/repos/${REPOSITORY}/releases/latest"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '%s\n' "错误：未找到 $1。" >&2
    exit 1
  fi
}

cleanup() {
  if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

require_command curl
require_command plutil

TEMP_DIR=$(mktemp -d "${BIN_DIR}/.release-download.XXXXXX")
RELEASE_JSON="${TEMP_DIR}/release.json"
trap cleanup 0
trap 'exit 1' HUP INT TERM

printf '%s\n' "正在查询 ${REPOSITORY} 的最新 release..."
if ! curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --retry 3 \
  --header 'Accept: application/vnd.github+json' \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  --output "$RELEASE_JSON" \
  "$API_URL"
then
  printf '%s\n' '错误：无法查询最新 release，请检查网络或稍后重试（GitHub 匿名 API 有频率限制）。' >&2
  exit 1
fi

TAG_NAME=$(plutil -extract tag_name raw -o - "$RELEASE_JSON")
ASSET_COUNT=$(plutil -extract assets raw -o - "$RELEASE_JSON")

case "$ASSET_COUNT" in
  ''|*[!0-9]*)
    printf '%s\n' '错误：GitHub API 返回了无效的附件列表。' >&2
    exit 1
    ;;
esac

if [ "$ASSET_COUNT" -eq 0 ]; then
  printf '%s\n' "错误：release ${TAG_NAME} 没有可下载的附件。" >&2
  exit 1
fi

printf '%s\n' "发现 release ${TAG_NAME}，共 ${ASSET_COUNT} 个附件。"

INDEX=0
while [ "$INDEX" -lt "$ASSET_COUNT" ]; do
  ASSET_NAME=$(plutil -extract "assets.${INDEX}.name" raw -o - "$RELEASE_JSON")
  ASSET_URL=$(plutil -extract "assets.${INDEX}.browser_download_url" raw -o - "$RELEASE_JSON")

  case "$ASSET_NAME" in
    ''|'.'|'..'|*/*)
      printf '%s\n' "错误：附件名称不安全：${ASSET_NAME}" >&2
      exit 1
      ;;
  esac

  printf '%s\n' "[$((INDEX + 1))/${ASSET_COUNT}] 正在下载 ${ASSET_NAME}..."
  if ! curl \
    --fail \
    --show-error \
    --location \
    --retry 3 \
    --output "${TEMP_DIR}/${ASSET_NAME}" \
    "$ASSET_URL"
  then
    printf '%s\n' "错误：${ASSET_NAME} 下载失败，bin 中的原文件未更改。" >&2
    exit 1
  fi

  INDEX=$((INDEX + 1))
done

INDEX=0
while [ "$INDEX" -lt "$ASSET_COUNT" ]; do
  ASSET_NAME=$(plutil -extract "assets.${INDEX}.name" raw -o - "$RELEASE_JSON")
  mv -f "${TEMP_DIR}/${ASSET_NAME}" "${BIN_DIR}/${ASSET_NAME}"
  INDEX=$((INDEX + 1))
done

printf '%s\n' "下载完成：${TAG_NAME}，附件已保存到 ${BIN_DIR}。"
