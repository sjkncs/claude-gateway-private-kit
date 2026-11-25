# 验证记录

日期：2026-11-25。所有通过项必须与实际命令输出对应。

- npm latest 元数据：Claude Code 2.1.332，Filesystem MCP 2.4.0。
- `node scripts/fetch-packages.mjs`：两份归档 SHA-512 完整性通过，分别 32525 和 63587 字节，未执行包内代码。
- `node scripts/validate-bundle.mjs`：11 个白名单文件、JSON 和基本秘密模式检查通过。
- `node --test tests/validator.test.mjs`：3 项通过，覆盖秘密样例、占位符和意外导出文件拒绝。
- PowerShell Parser.ParseFile：启动脚本语法通过；未实际启动客户端。
- 对照本机 gateway 配置值的额外脱敏检查：11 个文件通过，参考两个非空端点/认证值；配置值不写入本记录。
- Claude 归档 LICENSE.md 明示保留所有权利并引用法律协议，故未上传安装归档。Filesystem npm 清单引用 LICENSE，但实际归档缺失该文件，未上传其归档；不能据包名推断分发许可已核清。
- 后续运行核验：发现本机已安装官方命令 `claude`，`claude --version` 返回 2.1.329。未安装或覆盖该客户端，也未把该版本当作清单中的 2.1.332。
- 2026-11-25 05:52:09 UTC：使用本机现有 gateway 配置进行真实最小对话，退出码 0、结构化结果 success、精确预期文本匹配。未启用工具，未保存会话或原始输出。
- 2026-11-25 05:52:45 UTC：随机测试文件的真实读取调用通过，退出码 0；观察到 Read 工具调用、包含随机标记的成功工具结果及精确匹配的最终回复。只允许 Read，未执行写入、命令或 MCP 工具。已复现的发布脚本见 scripts/smoke-gateway.mjs。
- MCP 启动与调用、写入、会话恢复、交互式启动器实际运行：未执行。
- 发布脚本复测：`node scripts/smoke-gateway.mjs` 于 05:53:37 UTC 返回 passed=true；`node scripts/smoke-gateway.mjs --tool` 于 05:54:10 UTC 返回 passed=true，Read 调用及成功结果均被观察到。两次均退出 0，未保存原始输出。
- 已解析 WinGet 命令链接对应的实际客户端，Windows Authenticode 返回 Valid，签名者 Anthropic, PBC。
- 本次发布前检查：12 个白名单文件及私有配置值比对通过；3 项自测通过；`git diff --check` 通过。
- 第三方归档仅下载检查，不执行安装脚本；MCP 当前版本需 Node 24，本机 Node 22 不满足该组件要求。

本记录不包含完整请求、日志、个人目录或端点。
