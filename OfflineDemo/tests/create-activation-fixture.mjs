import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { createSignature } from '../scripts/offline-issuer.mjs';

const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const { x, y } = publicKey.export({ format: 'jwk' });
const device = randomBytes(32);
const valid = createSignature(privateKey, 200, device);
const bytes = Buffer.from(valid.slice(3), 'base64url');
bytes[98] ^= 1;
writeFileSync(process.argv[2], JSON.stringify({
    publicKey: Buffer.concat([Buffer.from([4]), Buffer.from(x, 'base64url'), Buffer.from(y, 'base64url')]).toString('base64'),
    device: device.toString('base64'),
    valid,
    tampered: 'WA-' + bytes.toString('base64url'),
    overCap: createSignature(privateKey, 201, device)
}));
