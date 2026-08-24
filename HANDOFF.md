# Project Handoff

> 本文件是 MiniOps Monitor Enterprise 的主要交接入口。  
> 当前权威状态以远程 `main` 和正式 Release 为准，不以当前 Windows dirty workspace 为准。

## 1. Project Overview

### 项目名称

MiniOps Monitor Enterprise。

### 项目解决的问题

项目是一个 Linux 单机资源监控服务，采集 CPU、内存、磁盘和负载，并通过 systemd 管理生命周期、权限和 journald 日志。

原始版本是教学性质的 Bash 脚本。企业化改造重点不是增加监控功能，而是建立可验证的软件生命周期：

```text
需求 → 行为契约 → 实现 → 测试 → CI → 打包 → Release → Linux 验收 → 故障排查
```

### 最终交付物

- Bash 监控脚本；
- systemd unit；
- 配置文件和安装/卸载脚本；
- unit、Bats、故障注入和集成测试；
- GitHub Actions；
- 确定性 tar 包和 SHA256 清单；
- GitHub Release `enterprise-v0.1.1`；
- Ubuntu 22.04/24.04 实机验收记录；
- 项目架构、运维、决策、展示和本交接文档。

真正完成的定义是：行为契约稳定，代码、测试、CI、发布资产和目标 Linux 环境验收证据可以追溯到明确 commit；本项目已达到该定义。

## 2. Current Status — Read This First

### 当前阶段

```text
Stage 6 — Final project handoff
```

### 当前总体状态

```text
✅ VERIFIED
```

### 当前权威基线

| Item | Value | Status |
| --- | --- | --- |
| Remote main | `492b252e13af8928e5818a6271f6684b851a1cb3` | ✅ VERIFIED |
| Release commit | `7c40469590a66113f8d2f81481da9040e9359411` | ✅ VERIFIED |
| Release tag | `enterprise-v0.1.1` | ✅ VERIFIED |
| Release tar SHA256 | `80b2a0899110e790e182ab7b27dc311966a5934176c7c548e42bf412bd0fcc7f` | ✅ VERIFIED |
| Current release | `enterprise-v0.1.1` | ✅ VERIFIED |
| P0/P1 blocker | None | ✅ VERIFIED |

### 已经完成

- 阶段 0 至阶段 5 企业化改造完成；
- P1 systemd 249 缺失 unit 兼容问题已修复；
- PR #5、PR #7、PR #8 已合并；
- main CI、tag workflow、artifact 和 Release 已通过；
- Ubuntu 22.04/systemd 249 实机验收通过；
- Ubuntu 24.04/systemd 255 实机验收通过；
- 最终项目文档和面试展示材料已归档。

### 当前未完成

没有阻塞正式 Release 的项目事项。

后续可选工作均属于 backlog，不应被误认为当前缺口：

- Prometheus 指标出口；
- 多机采集和集中式告警；
- 更完整的 systemd 集成自动化；
- 更严格的 systemd sandboxing；
- Bash 复杂度达到阈值后的 Python/Go 迁移。

### 当前最大阻塞

```text
No critical blocker.
```

### 下一步

下一次会话首先：

1. 阅读本文件；
2. 确认当前 checkout 指向最终 `main`，而不是旧的 P1 分支；
3. 检查工作区状态；
4. 不从 dirty workspace 打包或发布；
5. 进入项目学习计划，不重复 v0.1.1 Release/systemd 验收。

## 3. Project Stage Map

| Stage | Objective | Status | Exit condition |
| --- | --- | --- | --- |
| 0 | 基线、边界和行为契约 | ✅ VERIFIED | 基线、契约、backlog 和评审记录齐全 |
| 1 | 稳定性、配置和安装器边界 | ✅ VERIFIED | 配置错误、安装失败、回滚和卸载路径有测试 |
| 2 | Makefile、ShellCheck、shfmt、Bats | ✅ VERIFIED | 本地/CI 质量入口可重复执行 |
| 3 | 测试隔离和故障注入 | ✅ VERIFIED | 宿主机状态隔离，异常路径可诊断 |
| 4 | GitHub Actions、package、artifact | ✅ VERIFIED | 两套 Ubuntu matrix、package 和 checksum 通过 |
| 5 | 运维、安全、Release 和展示 | ✅ VERIFIED | Release 与 Linux 验收完成 |
| 6 | 最终文档和项目交接 | ✅ VERIFIED | HANDOFF 进入最终 main，状态和证据可继续追溯 |

## 4. Verified Completed Work

### 企业版实现

**Status:** ✅ VERIFIED

**Evidence**

- 正式 Release：`enterprise-v0.1.1`
- Release commit：`7c40469590a66113f8d2f81481da9040e9359411`
- Release：[enterprise-v0.1.1](https://github.com/hzd-git/miniops-monitor/releases/tag/enterprise-v0.1.1)
- 当前实现入口：[enterprise/src/miniops-monitor.sh](enterprise/src/miniops-monitor.sh)
- systemd unit：[enterprise/systemd/miniops-monitor-enterprise.service](enterprise/systemd/miniops-monitor-enterprise.service)

**What this proves**

- 该版本实现、配置、服务入口和发布来源已经明确。

**What this does NOT prove**

- 不证明项目具备多机监控、长期容量验证、高可用控制面或生产 SLA。

### 行为契约和日志

**Status:** ✅ VERIFIED

**Evidence**

- [enterprise/docs/behavior-contract.md](enterprise/docs/behavior-contract.md)
- CLI、退出码、配置格式、服务名和稳定日志字段已冻结；
- 结构化日志包含 `timestamp=`、`schema_version=1`、`level=`、`event=`。

**What this proves**

- 实现、测试和运维文档有共同的兼容性边界。

**What this does NOT prove**

- 不代表后续新增功能可以不经过契约评审。

### systemd 249/255 兼容修复

**Status:** ✅ VERIFIED

**Evidence**

- P1 修复 commit：`0e5dca02fb6b97d9b6ffb706f233856e170d3e27`
- PR #5：[systemd 249 compatibility fix](https://github.com/hzd-git/miniops-monitor/pull/5)
- 修复使用 `systemctl show ... --property=LoadState --value` 判断 unit 是否存在；
- Ubuntu 22.04/systemd 249 和 Ubuntu 24.04/systemd 255 均完成实机回归。

**What this proves**

- 首次安装和服务不存在时的卸载路径能区分正常缺失状态与真实 systemd/D-Bus 查询失败。

**What this does NOT prove**

- 不证明所有未来 systemd 版本或发行版输出都无需重新验证。

### 测试和故障注入

**Status:** ✅ VERIFIED

**Evidence**

- [enterprise/tests/unit](enterprise/tests/unit)
- [enterprise/tests/bats](enterprise/tests/bats)
- [enterprise/tests/integration/test_fault_injection.sh](enterprise/tests/integration/test_fault_injection.sh)
- [enterprise/docs/showcase/test-results.md](enterprise/docs/showcase/test-results.md)
- 覆盖配置错误、命令失败、服务不存在、stop/disable/daemon-reload 失败、回滚保留和卸载幂等。

**What this proves**

- 关键异常路径有可重复的 mock/fake 测试，并且正式版本已完成真实主机验收。

**What this does NOT prove**

- 不代表任意未覆盖的宿主机、权限模型或发行版组合都已验证。

### CI、打包和 Release

**Status:** ✅ VERIFIED

**Evidence**

- main workflow：[32686257505](https://github.com/hzd-git/miniops-monitor/actions/runs/32686257505)
- tag workflow：[32686677270](https://github.com/hzd-git/miniops-monitor/actions/runs/32686677270)
- 文档归档 PR #7：[PR #7](https://github.com/hzd-git/miniops-monitor/pull/7)
- 文档归档 PR #8：[PR #8](https://github.com/hzd-git/miniops-monitor/pull/8)
- main、tag 和 Release tar.gz SHA256 一致；
- Release 资产可在新目录独立校验。

**What this proves**

- v0.1.1 的 commit、tag、artifact、Release 和验收证据具备可追溯链路。

**What this does NOT prove**

- 不证明本地 dirty workspace 可以安全作为新的发布来源。

### Ubuntu 实机验收

**Status:** ✅ VERIFIED

**Evidence**

- Ubuntu 22.04/systemd 249：PASS；
- Ubuntu 24.04/systemd 255：PASS；
- 验证范围包括 checksum、dry-run、self-test、安装、生命周期、journald、配置恢复、启动失败恢复、默认卸载、purge 卸载和残留检查。

**What this proves**

- 正式 v0.1.1 Release 在两套目标 Ubuntu/systemd 环境完成必要验收。

**What this does NOT prove**

- 不代表修改业务代码后可以沿用旧实机证据；任何代码或 unit 变化都必须重新验证。

## 5. Work Executed but Not Fully Verified

当前没有已执行但仍缺少阶段退出条件的项目。

本次 HANDOFF 的内容、链接和状态检查在进入最终 main 前按 docs-only 变更进行审查；未重新运行 Release 或 systemd 测试，因为本次只增加交接文档。

## 6. Planned but Not Executed

以下均为 `📋 PLANNED — NOT EXECUTED`，不能作为当前执行证据：

- Prometheus 或其他指标出口；
- 多机采集和集中式告警；
- 数据库或长期时序存储；
- 更完整的 systemd 集成自动化；
- 更严格的 sandboxing；
- Bash 迁移 Python/Go；
- 新版本 Release。

## 7. Current Blockers and Open Items

### P0 — Blocking

None.

### P1 — Required Next

None for the released v0.1.1 project.

### P2 — Important but Non-blocking

- 真实 systemd 集成测试脚本的 cleanup 诊断仍可继续增强；
- 部分运行环境 warning 只属于诊断改进，不阻塞当前 Release。

### P3 — Deferred

- 多机、Prometheus、复杂告警、高可用和语言迁移。

## 8. Next Execution Plan

### Step 1 — 确认学习基线

**Objective**

以远程最终 `main=492b252e...` 和 `enterprise-v0.1.1` 为学习主线。

**Action**

1. 阅读本 HANDOFF；
2. 检查 `git status --short --branch`；
3. 检查 `enterprise/VERSION`；
4. 确认最终展示文档存在；
5. 确认没有误用旧的 `0e5dca02...` 工作区。

**Pass criteria**

- 当前 checkout 指向最终 main 或明确标记为历史分支；
- 版本为 `0.1.1`；
- 没有从 dirty workspace 生成 Release 的行为。

### Step 2 — 按文档顺序学习

**Objective**

建立从系统理解到发布验收的工程能力。

**Action**

1. 阅读 [行为契约](enterprise/docs/behavior-contract.md)；
2. 阅读 [架构说明](enterprise/docs/architecture.md)；
3. 阅读监控脚本、systemd unit、安装器和卸载器；
4. 阅读 unit/Bats/故障注入测试；
5. 阅读 CI、打包、运维和最终展示文档；
6. 复盘 systemd 249/255 P1 案例。

**Pass criteria**

能够解释 CLI、退出码、配置优先级、日志字段、服务生命周期、故障恢复和 Release 追溯链路。

### Step 3 — 选择低风险练习

只在新分支和专用测试目录中练习：

- 增加一个配置解析单元测试；
- 为现有故障注入补充一个 mock 场景；
- 修改文档并执行 Markdown 检查。

不得直接修改 Release、tag、正式主机或当前 dirty workspace。

## 9. New Session — Start Here

> **Do not restart the project from scratch.**
>
> Begin from the current verified state below.

1. 阅读本 `HANDOFF.md`；
2. 确认远程 `main=492b252e...`；
3. 确认当前版本为 `0.1.1`；
4. 检查工作区是否包含既有 staged 文件；
5. 使用 Enterprise 文档和最终 Release 作为学习基线；
6. 只在新分支中进行学习练习。

### Do NOT rerun

- 已通过的 v0.1.1 Release package/release 流程；
- Ubuntu 22.04/24.04 完整 systemd 验收；
- 已通过的故障注入和 CI 回归；
- 不涉及代码变化时的高成本 Release smoke。

只有代码、unit、配置契约、打包脚本或 Release 来源变化，才重新执行受影响验证。

### Do NOT trust as current evidence

- 本地 `codex/enterprise-systemd-249-compatibility` 分支；
- 本地 HEAD `0e5dca02...`；
- 本地 `enterprise/VERSION=0.1.0`；
- 本地 README 中“外部验收待完成”的旧描述；
- 本地 `main=2cc7b73...` 旧引用；
- `enterprise-v0.1.0` 作为当前正式 Release；
- 未绑定 commit/tag 的 dirty workspace 产物。

## 10. Key Files and Directories

| Path | Purpose | Status | Notes |
| --- | --- | --- | --- |
| `HANDOFF.md` | 权威交接入口 | CURRENT | 下一会话首先阅读 |
| `enterprise/src/miniops-monitor.sh` | 当前监控实现 | CURRENT | 保持行为契约 |
| `enterprise/systemd/miniops-monitor-enterprise.service` | 服务定义 | CURRENT | 真实 systemd 入口 |
| `enterprise/install.sh` | 安装和回滚 | CURRENT | 关键 systemd 操作不得静默失败 |
| `enterprise/uninstall.sh` | 卸载和恢复 | CURRENT | 删除前确认服务状态 |
| `enterprise/tests/` | 测试体系 | CURRENT | unit、Bats、fault injection、systemd |
| `enterprise/scripts/package.sh` | 确定性打包 | CURRENT | Release 来源必须是 clean commit/tag |
| `.github/workflows/enterprise.yml` | CI/CD | CURRENT | 不为 HANDOFF 单独修改 |
| `enterprise/docs/` | 架构、运维、证据和展示 | CURRENT | 以最终 main 为准 |
| `install.sh`, `src/miniops-monitor.sh`, `test.sh` | 当前本地旧工作区 staged 文件 | DO NOT MODIFY | 不纳入本交接或 Release |

## 11. Canonical Commands

### 检查当前状态

```bash
git status --short --branch
git rev-parse HEAD
git diff --check HEAD
git log --oneline -10
git tag
```

**Purpose**

确认当前 checkout、变更和 tag；不能替代远程 main/Release 核验。

### 企业版质量验证

```bash
cd enterprise
make verify
```

**Purpose**

执行 ShellCheck、shfmt、unit、Bats、fault injection 和 package-test。

**Known side effect**

可能生成 `enterprise/build/`；完成后使用：

```bash
make clean
```

### 安装前检查

```bash
bash install.sh --dry-run
bash src/miniops-monitor.sh --self-test
```

**Purpose**

检查安装前行为和确定性 self-test。

**Known side effect**

dry-run 不应写入系统路径；真实安装只在 disposable Ubuntu/systemd 主机执行。

### 服务排查

```bash
sudo systemctl status miniops-monitor-enterprise.service --no-pager
sudo journalctl -u miniops-monitor-enterprise.service -n 100 --no-pager -o cat
```

**Purpose**

定位服务状态、配置和采集错误。

## 12. Valid Evidence and Results

| Evidence | Status | Scope | Can prove | Cannot prove |
| --- | --- | --- | --- | --- |
| `RELEASE_COMMIT=7c404695...` | ✅ VERIFIED | v0.1.1 | Release 来源明确 | 后续未审查代码不会自动可信 |
| main workflow 32686257505 | ✅ VERIFIED | v0.1.1 main | CI/package/artifact 通过 | 其他 commit 自动通过 |
| tag workflow 32686677270 | ✅ VERIFIED | enterprise-v0.1.1 | tag/package/release 通过 | 新 tag 自动通过 |
| Release tar SHA256 | ✅ VERIFIED | v0.1.1 asset | 资产完整性和内容可校验 | 业务逻辑正确性 |
| Ubuntu 22.04 | ✅ VERIFIED | v0.1.1 | systemd 249 目标验收通过 | 其他发行版 |
| Ubuntu 24.04 | ✅ VERIFIED | v0.1.1 | systemd 255 目标验收通过 | 其他 systemd 版本 |
| PR #8 Actions 32699632153 | ✅ VERIFIED | docs-only | 最终文档 CI 通过 | package/release 重跑 |

## 13. Historical / Superseded Results

### 本地 P1 分支

**Status:** 🗃️ HISTORICAL / 🚫 SUPERSEDED

- HEAD：`0e5dca02...`
- `VERSION=0.1.0`
- 仍可用于理解 systemd 249 修复前后的演进；
- 不作为当前 Release、打包或学习最终状态的唯一来源。

### enterprise-v0.1.0

**Status:** 🗃️ HISTORICAL

- 仍保留为历史 Release；
- 不作为当前正式交付版本；
- 不删除、不覆盖、不重建。

### 本地 main 引用

**Status:** 🚫 SUPERSEDED

- 本地 `main=2cc7b73...` 是过期远程引用；
- 当前权威 main 为 `492b252e...`。

## 14. Pitfalls Already Encountered

- systemd 249 与 255 对不存在 unit 的 `systemctl is-enabled` 输出不同；
- package 分支构建不能强制执行 release tag 校验；
- SHA256 清单不能包含构建机绝对路径；
- install/uninstall 不能忽略 stop、disable、daemon-reload 等关键失败；
- 日志首字段必须是稳定的 `timestamp=`，不能使用裸时间戳；
- 不能把 CI、mock 或静态检查扩大解释为真实 systemd 验收；
- 不能从 dirty workspace 生成正式 Release；
- 文档只读 PR 不应被误认为 package 或 Release 验证；
- 当前本地 Git clone 因 SSL 证书链错误失败，不能通过关闭 SSL 校验绕过。

## 15. DO NOT REPEAT THESE MISTAKES

### ❌ DO NOT: 覆盖当前 dirty workspace

**What went wrong**

本地存在三个既有 staged 根目录文件。

**Why it is dangerous**

reset、checkout、pull 或 clean 可能覆盖用户修改。

**Correct procedure**

使用独立 clean worktree 或远程 GitHub clean commit；当前根目录只读保留。

### ❌ DO NOT: 使用本地旧版本发布

**What went wrong**

本地 `VERSION=0.1.0`、README 和 main 引用早于最终 v0.1.1。

**Why it is dangerous**

可能把旧文档、旧版本元数据和新 Release 混在一起。

**Correct procedure**

使用远程 `main=492b252e...` 或明确绑定的 `enterprise-v0.1.1`。

### ❌ DO NOT: 关闭 SSL 校验解决 clone 失败

**What went wrong**

独立 clone 遇到本地 CA 证书链错误。

**Why it is dangerous**

关闭 SSL 会削弱 Git 传输完整性和主机认证。

**Correct procedure**

使用已验证的 GitHub connector，或修复本地 CA/网络环境后再 clone。

### ❌ DO NOT: 把计划写成验证结果

**Correct procedure**

严格使用 `VERIFIED`、`EXECUTED`、`PLANNED`、`BLOCKED` 等状态；每个 PASS 都绑定实际命令、workflow、artifact 或主机日志。

## 16. Hard Constraints

- 不修改或删除 `enterprise-v0.1.0`、`enterprise-v0.1.1` tag 和 Release；
- 不修改业务代码、CLI、退出码、服务名、配置格式或日志契约；
- 不触碰当前本地 staged 的 `install.sh`、`src/miniops-monitor.sh`、`test.sh`；
- 不从 dirty workspace 生成发布物；
- 不使用关闭 SSL 校验的 Git 操作；
- 未重新执行的测试不得写成当前 PASS；
- 代码、unit、配置、打包脚本或 Release 来源变化后，必须重新执行受影响验证；
- 新需求先写入 backlog，不在当前收尾阶段扩大范围；
- 生产或真实 systemd 操作只在 disposable/专用主机执行。

## 17. Open Questions / Unknowns

### Q1 — 当前本地旧工作区是否需要物理切换到最终 main？

**Current knowledge**

当前本地工作区有既有 staged 文件，远程最终 main 已有可靠证据。

**Why unresolved**

直接同步可能覆盖用户修改；独立 clean worktree 已是安全替代。

**How to verify**

新会话在无 staged 变更的 clean checkout 中确认 `main=492b252e...`。

**Does it block next step?**

No。学习和后续文档工作使用最终远程 main。

## 18. Current Critical Path

```text
远程 main=492b252e...（已验证）
        ↓
HANDOFF.md 已进入最终 main（✅ VERIFIED）
        ↓
新会话阅读 HANDOFF 并确认 clean baseline
        ↓
开始项目学习计划
        ↓
只在新分支执行低风险练习
```

## 19. Evidence Links

- [最终 main commit（含 HANDOFF）](https://github.com/hzd-git/miniops-monitor/commit/492b252e13af8928e5818a6271f6684b851a1cb3)
- [HANDOFF docs-only PR #9](https://github.com/hzd-git/miniops-monitor/pull/9)
- [Release commit](https://github.com/hzd-git/miniops-monitor/commit/7c40469590a66113f8d2f81481da9040e9359411)
- [P1 修复 PR #5](https://github.com/hzd-git/miniops-monitor/pull/5)
- [文档 PR #7](https://github.com/hzd-git/miniops-monitor/pull/7)
- [文档 PR #8](https://github.com/hzd-git/miniops-monitor/pull/8)
- [main workflow](https://github.com/hzd-git/miniops-monitor/actions/runs/32686257505)
- [tag workflow](https://github.com/hzd-git/miniops-monitor/actions/runs/32686677270)
- [v0.1.1 Release](https://github.com/hzd-git/miniops-monitor/releases/tag/enterprise-v0.1.1)
