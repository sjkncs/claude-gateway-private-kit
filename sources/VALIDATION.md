# 验证记录

日期：2026-11-25。所有通过项必须与实际命令输出对应。

- npm latest 元数据：Claude Code 2.1.332，Filesystem MCP 2.4.0。
- `node scripts/fetch-packages.mjs`：两份归档 SHA-512 完整性通过，分别 32525 和 63587 字节，未执行包内代码。
- `node scripts/validate-bundle.mjs`：11 个白名单文件、JSON 和基本秘密模式检查通过。
- `node --test tests/validator.test.mjs`：3 项通过，覆盖秘密样例、占位符和意外导出文件拒绝。
- PowerShell Parser.ParseFile：启动脚本语法通过；未实际启动客户端。
- 对照本机 gateway 配置值的额外脱敏检查：11 个文件通过，参考两个非空端点/认证值；配置值不写入本记录。
- Claude 归档 LICENSE.md 明示保留所有权利并引用法律协议，故未上传安装归档。Filesystem npm 清单引用 LICENSE，但实际归档缺失该文件，未上传其归档；不能据包名推断分发许可已核清。
- 官方客户端安装、gateway 对话、模型工具调用、MCP 启动与调用：未执行。
- 第三方归档仅下载检查，不执行安装脚本；MCP 当前版本需 Node 24，本机 Node 22 不满足该组件要求。

本记录不包含完整请求、日志、个人目录或端点。
