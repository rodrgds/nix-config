#!/usr/bin/env bash
SOURCE="/home/rgo/JDSystem/30-39 Projects/32 Uni's Bad/32.11 Public-Facing"
TARGET="/home/rgo/dev/unis-bad/content"
mkdir -p "$TARGET"
cp -r "$SOURCE"/* "$TARGET/"
cd /home/rgo/dev/unis-bad
git add -A
git commit -m "$(date '+%Y-%m-%d %H:%M:%S')"
git push