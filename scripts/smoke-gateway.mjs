import { spawnSync } from 'node:child_process';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { randomBytes } from 'node:crypto';
import os from 'node:os';
import path from 'node:path';

// Credentials come only from the invoking process. Never print raw client output.
const toolTest = process.argv.includes('--tool');
for (const name of ['ANTHROPIC_BASE_URL', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_MODEL']) {
  if (!process.env[name]) throw new Error(`Missing environment variable: ${name}`);
}
const endpoint = new URL(process.env.ANTHROPIC_BASE_URL);
if (endpoint.protocol !== 'https:' || endpoint.username || endpoint.password || endpoint.search || endpoint.hash) {
  throw new Error('Use an HTTPS gateway base URL without embedded credentials, query or fragment.');
}
const env = { ...process.env, CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: '1' };
delete env.ANTHROPIC_API_KEY;
const directory = await mkdtemp(path.join(os.tmpdir(), 'gateway-smoke-'));
try {
  const marker = toolTest ? 'TOOL_FIXTURE_' + randomBytes(16).toString('hex') : 'GATEWAY_SMOKE_OK';
  if (toolTest) await writeFile(path.join(directory, 'smoke-fixture.txt'), marker);
  const prompt = toolTest
    ? 'Use the Read tool to read smoke-fixture.txt in the current directory. Reply with its exact contents.'
    : 'Reply exactly GATEWAY_SMOKE_OK.';
  const result = spawnSync('claude', [
    '--safe-mode', '--setting-sources', '', '--strict-mcp-config',
    '--no-session-persistence', '--system-prompt', prompt,
    '--tools', toolTest ? 'Read' : '', '--allowedTools', 'Read',
    '--output-format', 'stream-json', '--verbose', '-p', prompt
  ], { cwd: directory, env, encoding: 'utf8', timeout: 90000, windowsHide: true, maxBuffer: 2 * 1024 * 1024 });
  let events = [];
  try { events = result.stdout.trim().split('\n').map(line => JSON.parse(line)); } catch { /* Fail below, without exposing raw output. */ }
  const final = events.findLast(event => event.type === 'result');
  const readObserved = events.some(e => e.message?.content?.some(c => c.type === 'tool_use' && c.name === 'Read'));
  const readSuccess = events.some(e => e.message?.content?.some(c => c.type === 'tool_result' && !c.is_error && JSON.stringify(c.content).includes(marker)));
  const passed = result.status === 0 && final?.is_error === false && final?.result?.trim() === marker && (!toolTest || (readObserved && readSuccess));
  console.log(JSON.stringify({
    checkedAt: new Date().toISOString(), mode: toolTest ? 'read-tool' : 'dialogue',
    passed, exitCode: result.status, timedOut: result.error?.code === 'ETIMEDOUT',
    structuredResult: Boolean(final), readToolObserved: readObserved,
    successfulReadResultObserved: readSuccess, rawOutputRetained: false
  }, null, 2));
  if (!passed) process.exitCode = 1;
} finally {
  // Only remove this invocation's randomly created temporary directory.
  await rm(directory, { recursive: true, force: true });
}
