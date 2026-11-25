import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = new URL('../', import.meta.url);
const lock = JSON.parse(await readFile(new URL('sources/components.lock.json', root), 'utf8'));
await mkdir(new URL('.cache/', root), { recursive: true });
for (const entry of lock.components) {
  const url = new URL(entry.tarball);
  if (url.protocol !== 'https:' || url.hostname !== 'registry.npmjs.org' ||
      !/^[a-z0-9.-]+\.tgz$/.test(entry.file)) throw new Error('Invalid package source or filename');
  const response = await fetch(url, { signal: AbortSignal.timeout(60000), redirect: 'error' });
  if (!response.ok) throw new Error(`Download failed: ${response.status}`);
  const buffer = Buffer.from(await response.arrayBuffer());
  const actual = 'sha512-' + createHash('sha512').update(buffer).digest('base64');
  if (actual !== entry.integrity) throw new Error(`Integrity mismatch: ${entry.name}`);
  await writeFile(new URL('.cache/' + entry.file, root), buffer);
  console.log(`${entry.name}@${entry.version}: integrity PASS (${buffer.length} bytes)`);
}
console.log('Archives only. No package scripts executed. Cache: ' + fileURLToPath(new URL('.cache/', root)));
