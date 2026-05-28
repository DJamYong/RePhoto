---
name: git
description: Git 辅助技能 — 执行 git 操作（状态/提交/推送/分支/日志/差异）
---
# Git 操作技能

执行常见 git 操作的辅助技能。

## 可用命令

### 查看状态
```dart
// run_command: git status
```

### 查看简洁日志（最近 10 条）
```dart
// run_command: git log --oneline --graph -10
```

### 查看暂存区差异
```dart
// run_command: git diff --cached
```

### 查看工作区差异
```dart
// run_command: git diff
```

### 查看当前分支
```dart
// run_command: git branch
```

### 提交（需用户确认提交信息）
> 先 `git diff --cached` 查看暂存内容，再让用户填写提交信息，最后 `git commit -m "..."`

### 推送当前分支
```dart
// run_command: git push origin HEAD
```

### 拉取最新代码
```dart
// run_command: git pull --ff-only
```

### 暂存所有变更
```dart
// run_command: git add -A
```

### 撤销工作区修改
```dart
// run_command: git checkout -- <file>
```

### 创建并切换到新分支
```dart
// run_command: git checkout -b <branch-name>
```

## 使用说明

- 先了解用户意图，再选择对应命令
- **不要直接执行破坏性命令**（reset、push --force、delete branch 等），先向用户确认
- commit 前先用 `git diff --cached` 让用户审核变更内容
- 推荐使用 Conventional Commits 格式：`feat:` / `fix:` / `refactor:` / `docs:` / `chore:`
