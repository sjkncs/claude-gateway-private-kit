import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

export const allowed = [
  'Start-Windows.cmd', 'Start-Mac.command',
  '.gitignore', 'README.md', 'LICENSE', 'config/mcp.example.json',
  'config/collaboration.md', 'sources/components.lock.json', 'sources/VALIDATION.md',
  'scripts/start-claude.ps1', 'scripts/start-claude-macos.sh', 'scripts/fetch-packages.mjs',
  'scripts/validate-bundle.mjs', 'scripts/smoke-gateway.mjs', 'tests/validator.test.mjs',
  'skills/gateway-doctor/SKILL.md'
];
export function findings(text) {
  const rules = [
    /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
    /\b(?:sk-ant-|ghp_|github_pat_)[A-Za-z0-9_-]{16,}/,
    /\bBearer\s+[A-Za-z0-9_.-]{20,}/i,
    /[A-Z]:[\\/]Users[\\/](?!PUBLIC(?:[\\/]|$))[^\s"']+/i
  ];
  return rules.map((rule, index) => rule.test(text) ? index : -1).filter(x => x >= 0);
}
export async function validate(root) {
  const files = [];
  async function walk(dir, prefix = '') {
    for (const entry of await readdir(dir, { withFileTypes: true })) {
      if (!prefix && ['.git', '.cache'].includes(entry.name)) continue;
      const relative = prefix + entry.name;
      if (entry.isSymbolicLink()) throw new Error(`Symlink forbidden: ${relative}`);
      if (entry.isDirectory()) await walk(path.join(dir, entry.name), relative + '/');
      else files.push(relative);
    }
  }
  await walk(root);
  for (const file of files) {
    if (!allowed.includes(file)) throw new Error(`Unlisted file: ${file}`);
    const content = await readFile(path.join(root, file), 'utf8');
    if (findings(content).length) throw new Error(`Sensitive content pattern: ${file}`);
    if (file.endsWith('.json')) JSON.parse(content);
  }
  for (const file of allowed) if (!files.includes(file)) throw new Error(`Missing file: ${file}`);
  const mcp = JSON.parse(await readFile(path.join(root, 'config/mcp.example.json'), 'utf8'));
  if (!mcp.mcpServers.filesystem.args.includes('REPLACE_WITH_ALLOWED_DIRECTORY')) throw new Error('MCP directory must be a placeholder');
  return files.length;
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const root = fileURLToPath(new URL('../', import.meta.url));
  console.log(`Bundle PASS: ${await validate(root)} allowlisted files; JSON and basic secret patterns checked.`);
}
