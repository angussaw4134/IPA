import assert from 'node:assert/strict';
import { createPublicKey, randomBytes, verify } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { initialize, issue, openLedger } from '../scripts/offline-issuer.mjs';

test('200 distinct device claims, same-device retries, second-device rejection and signed output', () => {
    const root = mkdtempSync(join(tmpdir(), 'winter-activation-'));
    const owner = join(root, 'owner');
    const configPath = join(root, 'activation-public-key.json');
    try {
        initialize(owner, configPath);
        assert.throws(() => initialize(owner, configPath), { code: 'EEXIST' });
        const { maxDevices, publicKey } = JSON.parse(readFileSync(configPath));
        const bytes = Buffer.from(publicKey, 'base64');
        const verifier = createPublicKey({
            format: 'jwk',
            key: {
                kty: 'EC', crv: 'P-256',
                x: bytes.subarray(1, 33).toString('base64url'),
                y: bytes.subarray(33).toString('base64url')
            }
        });
        const keys = readFileSync(join(owner, '200-claim-keys.csv'), 'utf8').trim().split(/\r?\n/).slice(1).map(line => line.split(',')[1]);
        assert.equal(maxDevices, 200);
        assert.equal(keys.length, 200);
        assert.equal(new Set(keys).size, 200);
        const devices = keys.map(() => 'WD-' + randomBytes(32).toString('base64url'));
        const db = openLedger(owner);
        try {
            const first = issue(db, keys[0], devices[0]);
            assert.deepEqual(issue(db, keys[0].toLowerCase(), devices[0]), first);
            assert.deepEqual(issue(db, keys[1], devices[0]), first);
            assert.throws(() => issue(db, keys[0], devices[1]), /already assigned/);
            assert.throws(() => issue(db, keys[1], 'WD-bad'), /device code/);
            for (let i = 0; i < keys.length; i++) {
                const { slot, activation } = issue(db, keys[i], devices[i]);
                const token = Buffer.from(activation.slice(3), 'base64url');
                assert.equal(slot, i + 1);
                assert.equal(token.length, 99);
                assert.equal(token.readUInt16BE(1), slot);
                assert.equal(token.subarray(3, 35).toString('base64url'), devices[i].slice(3));
                assert.ok(verify('sha256', token.subarray(0, 35), { key: verifier, dsaEncoding: 'ieee-p1363' }, token.subarray(35)));
            }
            assert.equal(db.prepare('SELECT COUNT(device) AS assigned FROM claims').get().assigned, 200);
            assert.throws(() => issue(db, 'WINTER-' + randomBytes(16).toString('hex'), devices[0]), /not in your batch/);
        } finally {
            db.close();
        }
        const reopened = openLedger(owner);
        try {
            assert.throws(() => issue(reopened, keys[0], devices[1]), /already assigned/);
            assert.equal(issue(reopened, keys[0], devices[0]).slot, 1);
        } finally {
            reopened.close();
        }
    } finally {
        rmSync(root, { recursive: true, force: true });
    }
});
