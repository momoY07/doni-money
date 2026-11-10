// Downloads Apple Root CA - G3 (public) into ./certs for StoreKit JWS
// verification, and refuses it unless the SHA-256 fingerprint matches the
// value Apple publishes at https://www.apple.com/certificateauthority/.
// Run at deploy/build time: `npm run fetch-apple-roots`.
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOTS = [
  {
    file: 'AppleRootCA-G3.cer',
    url: 'https://www.apple.com/certificateauthority/AppleRootCA-G3.cer',
    sha256: '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179',
  },
];

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'certs');
fs.mkdirSync(dir, { recursive: true });

for (const root of ROOTS) {
  const res = await fetch(root.url);
  if (!res.ok) throw new Error(`Download failed (${res.status}) for ${root.file}`);
  const der = Buffer.from(await res.arrayBuffer());
  const got = createHash('sha256').update(der).digest('hex');
  if (got !== root.sha256) {
    throw new Error(`Fingerprint mismatch for ${root.file}: got ${got}. Not installed.`);
  }
  fs.writeFileSync(path.join(dir, root.file), der);
  console.log(`Installed ${root.file} (sha256 ${got})`);
}
