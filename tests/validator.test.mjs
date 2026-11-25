import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, symlink } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { findings, validate } from '../scripts/validate-bundle.mjs';

test('detect representative secrets and personal paths', () => {
  for (const sample of [
    ['sk', 'ant', 'x'.repeat(32)].join('-'),
    'ghp_' + 'x'.repeat(32),
    'Bearer ' + 'x'.repeat(32),
    '-----BEGIN ' + 'PRIVATE KEY-----',
    ['C:', 'Users', 'someone', 'settings.json'].join(String.fromCharCode(92))
  ]) assert.ok(findings(sample).length > 0);
});
test('placeholders are allowed', () => {
  assert.deepEqual(findings('ANTHROPIC_AUTH_TOKEN = <YOUR_TOKEN>'), []);
});
test('unlisted exports fail closed', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'gateway-kit-test-'));
  await writeFile(path.join(root, 'unexpected.txt'), 'example');
  await assert.rejects(validate(root), /Unlisted file/);
});
