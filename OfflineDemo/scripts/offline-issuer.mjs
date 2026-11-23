import { createHash, generateKeyPairSync, randomBytes, sign } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { createInterface } from 'node:readline/promises';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const MAX_DEVICES = 200;
const databaseName = 'activation-ledger.sqlite';
const claimDigest = key => createHash('sha256').update(key.toUpperCase()).digest('hex');

export function createSignature(signer, slot, device) {
    const payload = Buffer.alloc(35);
    payload[0] = 1;
    payload.writeUInt16BE(slot, 1);
    device.copy(payload, 3);
    const signature = sign('sha256', payload, { key: signer, dsaEncoding: 'ieee-p1363' });
    return 'WA-' + Buffer.concat([payload, signature]).toString('base64url');
}

export function initialize(folder, publicConfigPath) {
    mkdirSync(folder, { mode: 0o700 });
    const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
    const { x, y } = publicKey.export({ format: 'jwk' });
    const publicBytes = Buffer.concat([Buffer.from([4]), Buffer.from(x, 'base64url'), Buffer.from(y, 'base64url')]);
    const db = new DatabaseSync(join(folder, databaseName));
    const csv = ['Slot,Claim key'];
    try {
        db.exec(`
            CREATE TABLE signing_key (pem TEXT NOT NULL);
            CREATE TABLE claims (
                slot INTEGER PRIMARY KEY CHECK (slot BETWEEN 1 AND 200),
                digest TEXT NOT NULL UNIQUE,
                device TEXT UNIQUE,
                activation TEXT
            );
            BEGIN IMMEDIATE;
        `);
        db.prepare('INSERT INTO signing_key VALUES (?)').run(privateKey.export({ type: 'pkcs8', format: 'pem' }));
        const insert = db.prepare('INSERT INTO claims (slot, digest) VALUES (?, ?)');
        for (let slot = 1; slot <= MAX_DEVICES; slot++) {
            const claim = 'WINTER-' + randomBytes(16).toString('hex').toUpperCase();
            insert.run(slot, claimDigest(claim));
            csv.push(slot + ',' + claim);
        }
        db.exec('COMMIT');
    } finally {
        db.close();
    }
    writeFileSync(join(folder, '200-claim-keys.csv'), csv.join('\r\n') + '\r\n', { flag: 'wx', mode: 0o600 });
    writeFileSync(publicConfigPath, JSON.stringify({ maxDevices: MAX_DEVICES, publicKey: publicBytes.toString('base64') }) + '\n', { flag: 'wx' });
}

export function openLedger(folder) {
    const db = new DatabaseSync(join(folder, databaseName), { readOnly: true });
    db.close();
    const ledger = new DatabaseSync(join(folder, databaseName));
    ledger.exec('PRAGMA busy_timeout = 5000');
    return ledger;
}

export function issue(db, claim, requestCode) {
    claim = claim.trim();
    requestCode = requestCode.replace(/\s/g, '');
    if (!/^WINTER-[a-f0-9]{32}$/i.test(claim)) throw new Error('Enter a claim key from your CSV.');
    if (!/^WD-[A-Za-z0-9_-]{43}$/.test(requestCode)) throw new Error('Paste the device code from the iPhone.');
    const device = Buffer.from(requestCode.slice(3), 'base64url');
    if (device.length !== 32 || device.toString('base64url') !== requestCode.slice(3)) {
        throw new Error('The iPhone device code was copied incorrectly.');
    }

    db.exec('BEGIN IMMEDIATE');
    try {
        const row = db.prepare('SELECT * FROM claims WHERE digest = ?').get(claimDigest(claim));
        if (!row) throw new Error('This claim key is not in your batch.');
        if (row.device === requestCode) {
            db.exec('COMMIT');
            return { slot: row.slot, activation: row.activation };
        }
        if (row.device) throw new Error('That claim key was already assigned to another iPhone.');
        const existing = db.prepare('SELECT slot, activation FROM claims WHERE device = ?').get(requestCode);
        if (existing) {
            db.exec('COMMIT');
            return { slot: existing.slot, activation: existing.activation };
        }
        const { pem } = db.prepare('SELECT pem FROM signing_key').get();
        const activation = createSignature(pem, row.slot, device);
        db.prepare('UPDATE claims SET device = ?, activation = ? WHERE slot = ?').run(requestCode, activation, row.slot);
        db.exec('COMMIT');
        return { slot: row.slot, activation };
    } catch (error) {
        db.exec('ROLLBACK');
        throw error;
    }
}

async function main() {
    const [action, a, b] = process.argv.slice(2);
    if (action === 'init' && a && b) {
        initialize(resolve(a), resolve(b));
        console.log('Created exactly 200 claim keys and a public verification key.');
        return;
    }
    const db = openLedger(dirname(fileURLToPath(import.meta.url)));
    try {
        const { total, assigned } = db.prepare('SELECT COUNT(*) AS total, COUNT(device) AS assigned FROM claims').get();
        console.log(`Assigned ${assigned} of ${total} slots. ${total - assigned} available.`);
        if (action === 'status') return;
        const input = createInterface({ input: process.stdin, output: process.stdout });
        try {
            const claim = await input.question('Claim key from your CSV: ');
            const request = await input.question('Device code from the iPhone: ');
            const result = issue(db, claim, request);
            console.log(`\nSend this activation code to the customer for slot ${result.slot}:\n${result.activation}\n`);
        } finally {
            input.close();
        }
    } finally {
        db.close();
    }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    main().catch(error => {
        console.error(error.message);
        process.exitCode = 1;
    });
}
