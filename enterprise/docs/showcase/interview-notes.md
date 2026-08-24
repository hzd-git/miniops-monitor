# MiniOps Monitor Enterprise 面试展示笔记

## 30 秒项目介绍

我把一个教学性质的 Bash 资源监控脚本，逐步改造成了一个可验证、可发布、可在真实 Linux 主机验收的小型企业工程案例。项目继续使用 Bash + systemd，冻结 CLI、退出码、服务名、配置格式和日志契约，补齐了配置校验、错误处理、安装卸载回滚、单元和故障注入测试、GitHub Actions、确定性打包、SHA256、GitHub Release，以及 Ubuntu 22.04/24.04 的 systemd 实机验证。最终 v0.1.1 的发布来源、CI、artifact、Release 和两套 Ubuntu 验收结果都可以追溯。

## 3 分钟技术介绍

项目边界是单机 Linux 资源采集，不承担多机监控和告警平台职责。systemd unit 管理监控脚本的启动、重启、权限和 journald 输出；脚本从 `/etc/default/miniops-monitor-enterprise` 加载配置，校验采样间隔后采集 CPU、内存、磁盘和负载，并输出带有 `timestamp=`、`schema_version=1`、`level=`、`event=` 的结构化日志。

工程化改造先冻结行为契约，再按稳定性、工程基础、测试、自动化交付和实机验收推进。测试不是只测正常路径，而是通过 fake/fixture 和故障注入验证服务不存在、systemd 查询失败、stop/disable/daemon-reload 失败、配置错误和安装回滚。CI 在 Ubuntu 22.04/24.04 上运行 ShellCheck、shfmt、unit/Bats、fault injection、package-test 和 systemd unit 语法检查。

发布时从经过 CI 验证的 commit 生成确定性 tar 包，检查包内文件、权限和版本一致性，生成相对路径 SHA256 清单，再由匹配 tag 触发 Release。正式 v0.1.1 资产在两台真实 Ubuntu 主机上完成 checksum、安装、完整 systemd 生命周期、journald、配置错误恢复、受控启动失败恢复、默认卸载、purge 卸载和残留检查。

这个项目的核心成果不是监控指标数量，而是能够说明一个小系统如何被安全修改、自动验证、重复发布和在真实环境中定位问题。

## 深挖问题准备

### 为什么选择 Bash，而不是 Go/Python？

当前功能主要是读取 Linux 现成信息、加载简单配置、调用系统命令并交给 systemd 管理，Bash 与运行环境天然贴合，依赖少、部署简单，也能直接训练 Linux 服务工程能力。

我没有把 Bash 当成通用业务语言。若出现复杂业务规则、持久化状态、网络 API、并发调度、较强类型约束、丰富库生态或跨平台支持，我会优先评估迁移 Python 或 Go。选择应由复杂度和运维目标驱动，而不是为了“企业级”预先引入新语言。

### 为什么暂不引入 Prometheus？

当前项目目标是完整演示单机服务生命周期，而不是建设指标平台。引入 Prometheus 会同时带来指标协议、网络端口、抓取配置、暴露面和部署依赖；在没有真实多机或集中观测需求时，收益不足以抵消维护成本。

如果后续需要多机采集、统一查询、告警规则或长期趋势分析，再根据接口和安全要求设计 Prometheus exporter 或其他指标出口，而不是直接把当前小脚本扩展成平台。

### 如何保证 systemd 服务可靠？

我把可靠性拆成可验证的环节：

1. 固定 unit、配置和日志行为契约；
2. 对启动参数和配置做严格校验；
3. 让关键 systemd 操作失败立即暴露，不继续删除可能仍在使用的文件；
4. 使用 `systemctl status/show` 和 journald 提供诊断信息；
5. 用 `DynamicUser`、`NoNewPrivileges` 等已验证约束降低权限风险；
6. 用 fake systemctl 覆盖失败注入，再用 Ubuntu 22.04/24.04 实机验证真实生命周期；
7. 发布前把 commit、tag、artifact SHA256 和主机证据串成一条链。

### 如何处理 Ubuntu 版本差异？

不依赖某个 systemd 版本的错误文本。一次实际问题中，systemd 249 和 255 对“unit 不存在”的 `is-enabled` 输出不同，导致首次安装路径判断错误。修复后先用 `systemctl show ... LoadState` 判断 unit 是否存在：只有成功得到精确的 `not-found` 才走缺失路径；查询失败仍按故障处理。随后用 mock 覆盖两种版本风格，并在两套真实主机重新回归。

### 如何定位 systemd 兼容问题？

先保留命令的 stdout、stderr 和 exit code，分别在 systemd 249/255 上复现“unit 不存在、disabled、enabled 和查询失败”。对比发现原脚本把版本相关的 `is-enabled` 诊断文本当成唯一判断依据。于是把问题收敛为“存在性查询不稳定”，用 `LoadState` 建立稳定判定，再补充真实失败不被吞掉的测试，最后执行两套实机完整回归。

### 如何设计回归测试？

先按状态划分，而不是按代码行划分：

- unit 不存在：systemd 249 多行诊断和 255 `not-found`；
- unit 存在：enabled、disabled；
- 查询失败：systemctl/D-Bus 错误；
- 事务失败：stop、disable、daemon-reload 失败；
- 恢复路径：文件保留、服务状态恢复、卸载幂等。

CI 验证快速、重复的 mock 和静态检查；真实 Ubuntu 验收验证 systemd/journald 的环境行为。正式 Release 还要做独立 checksum 和 smoke，避免把某一层证据误当成全部通过。

## 可以继续追问的工程问题

### 如果线上升级失败，如何回滚？

先停止服务并读取 status/journal，确认失败发生在 systemd 状态、配置还是文件部署。保留当前文件和备份，恢复上一个已验证的 Release 包，执行 daemon-reload、enable/start，并再次检查 active、日志和版本。不会在服务仍运行时直接删除脚本。

### 如何证明发布包没有被工作区污染？

发布只从经过 CI 验证的 commit/tag 的干净 checkout 构建；package 脚本固定文件集合、排序、时间戳、owner/group 和 gzip 参数；artifact 和 Release 资产在独立目录做 SHA256、tar 清单和权限检查。

### 什么时候应该迁移到 Python/Go？

当采集逻辑需要持久化状态、复杂并发、网络协议、较强类型约束、丰富库生态或跨平台支持时迁移。迁移前先以基准、接口和回滚策略证明收益，避免仅因为“看起来更企业”而增加系统复杂度。

## 展示证据入口

- [最终项目总结](final-summary.md)
- [工程能力复盘](engineering-retrospective.md)
- [发布记录](ci-record.md)
- [测试结果](test-results.md)
- [GitHub Release](https://github.com/hzd-git/miniops-monitor/releases/tag/enterprise-v0.1.1)
