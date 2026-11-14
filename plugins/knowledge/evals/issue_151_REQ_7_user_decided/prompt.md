---
description: "issue #151 REQ-7: AIの提案がない判断には、評価（result）を付けない"
max_turns: 10
runs: 3
allowed_tools: [Read, Glob, Grep, Skill]
tags: [issue-151, REQ-7, REQ-8]
---

次のやりとりから、ユーザーが決めた判断を、生の判断として `./raw` に保存してください。日時は 2026-11-14 09:30:12 です。

## やりとり

AI: 通知の送り方で、決めておきたいことはありますか。

ユーザー: 通知のメールは、非同期で送るようにして。
