#!/usr/bin/env bash
# -------------------------------------------------
# 一键部署脚本（改进版）
# 1️⃣ 把指定文件或全部改动提交到 Git
# 2️⃣ 生成 Hexo 页面并推送到 GitHub Pages
# -------------------------------------------------

set -e   # 任何错误立即退出

# ---------- 参数 ----------
# 第一个参数（必填）是本次提交的说明
# 第2...N 参数是要 add 的文件路径（可选）
COMMIT_MSG="${1:-Site update: $(date +'%Y-%m-%d %H:%M:%S')}"

# ---------- 步骤 1：Git ----------
echo "=== Git commit & push ==="
if [ "$#" -gt 1 ]; then
  # 参数2及以后视为文件路径列表
  files="${@:2}"
  echo "Adding specified files: $files"
  git add $files
else
  echo "No specific files provided, adding all changed files."
  git add .
fi

git commit -m "$COMMIT_MSG"

git push      # 推到当前分支（默认 main）

# ---------- 步骤 2：Hexo ----------
echo "=== Hexo clean / generate / deploy ==="
npx hexo clean
npx hexo generate
npx hexo deploy

echo "✅ 部署完成 🎉"
