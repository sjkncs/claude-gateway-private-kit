# Claude Code 授权 Gateway 配置包（Windows 与 macOS）

## 下载后开始使用

按本项目的网络配置，启动前请先连接 VPN 的美国节点，并在代理客户端开启“智能代理”模式。连接成功后再打开启动器。

打开 [最新发布版](https://github.com/sjkncs/claude-gateway-private-kit/releases/latest)，用有仓库访问权的 GitHub 账号下载附件 **Claude-Gateway-Kit.zip**，完整解压。两个系统使用同一个压缩包。

首次使用请准备好自己的 HTTPS 网关地址、模型 ID 和令牌。启动器会检查 Claude Code。已安装时直接启动，首次安装时请保持联网。Windows 可按提示通过 WinGet 安装，Mac 可按提示通过 Homebrew 安装。缺少对应的软件包管理器时，启动器会打开 [官方安装页](https://code.claude.com/docs/en/setup)，安装完成后重新打开入口即可。

| 系统 | 解压后的操作 |
| --- | --- |
| Windows | 双击 `Start-Windows.cmd`，在窗口中输入要工作的项目目录。 |
| macOS | 双击 `Start-Mac.command`，在终端中输入项目目录。如果从终端启动，可输入 `/bin/bash `，再将该文件拖入终端并回车。 |

按提示输入网关地址、模型 ID 和令牌。启动后输入 `/status` 查看当前连接。两个快捷入口均启用协作模式。

## macOS 快速启动

安装 Claude Code 后，在终端运行 `claude --version` 确认可用。进入你要处理的项目目录，再运行下面的命令，把引号中的路径换成下载的 kit 所在位置。

```bash
/bin/bash "/实际路径/claude-gateway-private-kit/scripts/start-claude-macos.sh" --collaborative
```

依次输入自己的 HTTPS gateway 地址、模型 ID 和令牌。输入令牌时屏幕不会显示字符。省略 `--collaborative` 即可沿用客户端原有权限模式。

## Windows 启动参数

需要 Claude 自行处理常规决策时，在启动命令末尾加上 `-Collaborative`。启动器会为本次会话请求 Auto 权限模式，并载入 [协作规则](config/collaboration.md)，让 Claude 合并必要的提问、复用已读材料并在交付前验证结果。可在客户端模式菜单查看实际生效的权限模式。省略该参数时沿用客户端原有设置。

本包用于把 Claude Code 连接到使用者已有授权的 Anthropic API 兼容 gateway。每位使用者需要自己的有效凭据；本包不提供账号、共享令牌、登录绕过补丁或服务端 gateway。不要把 API 接入理解为 Claude 网页、桌面或云端全部功能均可使用。

## 已整理的经验与边界

本机配置中确认存在 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_MODEL` 等变量；地址和变量值未导出。未找到能可靠归属于相邻任务的 gateway 源码和完整验收记录，因此本仓库提供官方接入方法及脱敏模板，不宣称复刻了相邻任务的全部成果。原有第三方 Claude 包装器未打包，其来源、完整性和许可尚未确认。本机个人 skills 内容、会话、Cookie 和认证文件均未复制。

## 使用

1. 阅读 `sources/components.lock.json` 及官方文档。运行 `node scripts/fetch-packages.mjs`，下载锁定版本安装归档到被 Git 忽略的 `.cache`，并验证 npm 完整性摘要。该步骤不执行包内脚本，也不等于安装成功。
2. 阅读归档内 README、许可和安装脚本。按 [Claude Code 官方安装说明](https://code.claude.com/docs/en/setup) 安装官方版本。锁定版本见清单；安装需要联网，npm 路径可能执行官方安装脚本并下载平台二进制。本仓库不重分发专有安装程序。
3. 在准备工作的项目目录运行 `powershell -NoProfile -File <本仓库路径>/scripts/start-claude.ps1`。输入自己的 HTTPS gateway 地址、模型 ID 和令牌。令牌隐藏输入，只注入当前子进程环境，结束后恢复原有变量；不会修改用户设置文件。此前已有的用户或组织设置仍可能影响客户端，需自行核对 `/status`。请勿在录屏、命令历史或日志中输入凭据。
4. Skills：将 `skills/gateway-doctor` 文件夹复制到目标项目的 `.claude/skills/`，使用 `/gateway-doctor` 排查配置。
5. MCP：审阅 `config/mcp.example.json`，把 `REPLACE_WITH_ALLOWED_DIRECTORY` 换成目标项目中明确允许访问的目录，再保存为该项目的 `.mcp.json`。Filesystem MCP 能读写允许目录，仅给必要权限。首次使用会下载并执行锁定的第三方包；先审阅其许可、依赖和入口。该版本要求 Node 24 或以上，与 Claude Code 自身要求分别核对。通过 `/mcp` 检查服务器状态。

## 验收

本地检查：`node scripts/validate-bundle.mjs`；扫描器自测：`node --test tests/validator.test.mjs`。检查是有限的静态校验，不保证识别所有秘密。发布前还应检查暂存清单与实际差异。

2026-11-25 本机官方客户端 2.1.329 已通过一次真实 gateway 对话和一次真实 `Read` 工具调用；详情见 `sources/VALIDATION.md`。锁定清单中的 2.1.332 是归档版本，尚未安装验证，不能与运行版本混同。MCP、写入、会话恢复、全部功能均未验收。

可复现检查：在自己的授权环境中设置 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_MODEL` 后，运行 `node scripts/smoke-gateway.mjs`，再运行 `node scripts/smoke-gateway.mjs --tool`。测试会产生实际 API 使用费用，只输出脱敏的通过/失败状态。它关闭普通自定义项和非显式 MCP，使用临时目录，不保存会话；只读测试用随机内容检查真实工具调用，不测试写入。失败退出码为 1，不输出服务端原始错误；需要时在本地排查，不上传未经脱敏的日志。

实际部署仍需分别核对 `/status` 模型与提供方、经允许的临时文件写入、`/mcp` 工具发现和调用，以及重开后的状态。上述小范围测试不证明完整可用。

## 来源与更新

版本与下载地址来自 npm 官方注册表，记录于锁定清单；“最新”仅指该次查询的 latest 标签，不自动追踪后续变更。归档下载后需重新核对许可。原创建文档与脚本使用本仓库 LICENSE；第三方组件遵守各自条款。

- [官方 Gateway 接入](https://code.claude.com/docs/en/llm-gateway-connect)
- [Gateway 兼容性概览](https://code.claude.com/docs/en/llm-gateway)
- [官方 MCP 文档](https://code.claude.com/docs/en/mcp)
- [官方 Skills 文档](https://code.claude.com/docs/en/skills)
- [Filesystem MCP 官方仓库](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem)
