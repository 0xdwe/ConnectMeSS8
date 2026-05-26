// Connect Me — Firestore rules unit tests.
//
// Runs against the Firebase emulator using @firebase/rules-unit-testing.
// See README.md in this folder for how to invoke the suite locally.
//
// The matrix below covers ownership and document-shape enforcement for
// `users/{uid}/memories/{contactId}`. It deliberately exercises both
// allow paths and deny paths, including malformed payloads (missing
// keys, extra keys, wrong types, oversized markdown).

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp } = require('firebase/firestore');

const PROJECT_ID = 'connect-me-rules-test';
const ALICE = 'alice-uid';
const BOB = 'bob-uid';

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  if (testEnv) {
    await testEnv.clearFirestore();
  }
});

// Helpers -------------------------------------------------------------

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function anonDb() {
  return testEnv.unauthenticatedContext().firestore();
}

function memoryDocRef(db, uid, contactId) {
  return doc(db, 'users', uid, 'memories', contactId);
}

function memoriesCollectionRef(db, uid) {
  return collection(db, 'users', uid, 'memories');
}

function wellFormedMemory(overrides = {}) {
  return {
    markdown: '# Sarah\n\nNotes about Sarah.',
    updatedAt: Timestamp.fromDate(new Date('2026-05-24T00:00:00Z')),
    schemaVersion: 1,
    ...overrides,
  };
}

// Seed a doc through the privileged context so per-test arrange steps
// are not blocked by the rules being tested.
async function seedMemory(uid, contactId, data = wellFormedMemory()) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(memoryDocRef(ctx.firestore(), uid, contactId), data);
  });
}

function userDocRef(db, uid) {
  return doc(db, 'users', uid);
}

function wellFormedUserDoc(overrides = {}) {
  return {
    migratedFromDiskAt: Timestamp.fromDate(new Date('2026-05-24T00:00:00Z')),
    ...overrides,
  };
}

async function seedUserDoc(uid, data = wellFormedUserDoc()) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(userDocRef(ctx.firestore(), uid), data);
  });
}

function connectionDocRef(db, uid, contactId) {
  return doc(db, 'users', uid, 'connections', contactId);
}

function connectionsCollectionRef(db, uid) {
  return collection(db, 'users', uid, 'connections');
}

function wellFormedConnection(overrides = {}) {
  return {
    id: 'sarah',
    name: 'Sarah Chen',
    category: 'Friend',
    avatar: 'sarah',
    bondScore: 85,
    nextStep: 'Send the article on neural rendering',
    lastContact: Timestamp.fromDate(new Date('2026-05-20T00:00:00Z')),
    knownSince: Timestamp.fromDate(new Date('2024-01-15T00:00:00Z')),
    preferredChannels: ['imessage', 'email'],
    schemaVersion: 1,
    updatedAt: Timestamp.fromDate(new Date('2026-05-26T00:00:00Z')),
    // Optional fields included by default; specific tests omit them.
    email: 'sarah@example.com',
    notes: 'Knows the team at Anthropic.',
    isSample: false,
    ...overrides,
  };
}

async function seedConnection(uid, contactId, data) {
  const payload = data ?? wellFormedConnection({ id: contactId });
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(connectionDocRef(ctx.firestore(), uid, contactId), payload);
  });
}

function interactionDocRef(db, uid, interactionId) {
  return doc(db, 'users', uid, 'interactions', interactionId);
}

function interactionsCollectionRef(db, uid) {
  return collection(db, 'users', uid, 'interactions');
}

function wellFormedInteraction(overrides = {}) {
  return {
    id: 'i-1',
    contactId: 'sarah',
    type: 'interaction',
    title: 'Coffee chat',
    note: 'Discussed the migration project',
    date: Timestamp.fromDate(new Date('2026-05-20T15:00:00Z')),
    schemaVersion: 1,
    updatedAt: Timestamp.fromDate(new Date('2026-05-26T00:00:00Z')),
    // Optional fields included by default; specific tests omit them.
    attachments: ['notes.md'],
    source: 'manual',
    ...overrides,
  };
}

async function seedInteraction(uid, interactionId, data) {
  const payload = data ?? wellFormedInteraction({ id: interactionId });
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      interactionDocRef(ctx.firestore(), uid, interactionId),
      payload,
    );
  });
}

// Tests ---------------------------------------------------------------

describe('users/{uid}/memories/{contactId} — ownership', () => {
  test('owner can read own memory doc', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertSucceeds(getDoc(memoryDocRef(authedDb(ALICE), ALICE, 'sarah')));
  });

  test('other authenticated user cannot read another user’s memory doc', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(getDoc(memoryDocRef(authedDb(BOB), ALICE, 'sarah')));
  });

  test('owner can list own memories collection', async () => {
    await seedMemory(ALICE, 'sarah');
    await seedMemory(ALICE, 'mike');
    await assertSucceeds(getDocs(memoriesCollectionRef(authedDb(ALICE), ALICE)));
  });

  test('other authenticated user cannot list another user’s memories collection', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(getDocs(memoriesCollectionRef(authedDb(BOB), ALICE)));
  });

  test('owner can create well-formed own memory doc', async () => {
    await assertSucceeds(
      setDoc(memoryDocRef(authedDb(ALICE), ALICE, 'sarah'), wellFormedMemory()),
    );
  });

  test('other authenticated user cannot create memory doc at someone else’s path', async () => {
    await assertFails(
      setDoc(memoryDocRef(authedDb(BOB), ALICE, 'sarah'), wellFormedMemory()),
    );
  });

  test('owner can update own memory doc with well-formed payload', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertSucceeds(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ markdown: '# Sarah\n\nUpdated notes.' }),
      ),
    );
  });

  test('other authenticated user cannot update another user’s memory doc', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(
      setDoc(
        memoryDocRef(authedDb(BOB), ALICE, 'sarah'),
        wellFormedMemory({ markdown: '# Sarah\n\nHacked notes.' }),
      ),
    );
  });

  test('owner can delete own memory doc', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertSucceeds(deleteDoc(memoryDocRef(authedDb(ALICE), ALICE, 'sarah')));
  });

  test('other authenticated user cannot delete another user’s memory doc', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(deleteDoc(memoryDocRef(authedDb(BOB), ALICE, 'sarah')));
  });
});

describe('default deny outside scope', () => {
  test('owner is denied at a sibling path on their own user doc (e.g. notes)', async () => {
    // Pass 4.2 only opens up users/{uid}/memories/{contactId} and the
    // user doc itself. Anything else under the same user — even though
    // the user owns the parent path — should fall through to
    // Firestore's default deny.
    await assertFails(
      getDoc(doc(authedDb(ALICE), 'users', ALICE, 'notes', 'foo')),
    );
  });
});

describe('users/{uid} — sentinel ownership', () => {
  test('owner can read their own user doc', async () => {
    await seedUserDoc(ALICE);
    await assertSucceeds(getDoc(userDocRef(authedDb(ALICE), ALICE)));
  });

  test('owner can create their user doc with the sentinel', async () => {
    await assertSucceeds(
      setDoc(userDocRef(authedDb(ALICE), ALICE), wellFormedUserDoc()),
    );
  });

  test('owner can update the sentinel timestamp', async () => {
    await seedUserDoc(ALICE);
    await assertSucceeds(
      setDoc(
        userDocRef(authedDb(ALICE), ALICE),
        wellFormedUserDoc({
          migratedFromDiskAt: Timestamp.fromDate(new Date('2026-06-01T00:00:00Z')),
        }),
      ),
    );
  });

  test('other authenticated user cannot read another user doc', async () => {
    await seedUserDoc(ALICE);
    await assertFails(getDoc(userDocRef(authedDb(BOB), ALICE)));
  });

  test('other authenticated user cannot write another user doc', async () => {
    await assertFails(
      setDoc(userDocRef(authedDb(BOB), ALICE), wellFormedUserDoc()),
    );
  });

  test('anonymous read denied', async () => {
    await seedUserDoc(ALICE);
    await assertFails(getDoc(userDocRef(anonDb(), ALICE)));
  });

  test('anonymous write denied', async () => {
    await assertFails(
      setDoc(userDocRef(anonDb(), ALICE), wellFormedUserDoc()),
    );
  });

  test('owner cannot write an unknown field', async () => {
    await assertFails(
      setDoc(
        userDocRef(authedDb(ALICE), ALICE),
        wellFormedUserDoc({ extra: 'not allowed' }),
      ),
    );
  });

  test('owner cannot write migratedFromDiskAt as the wrong type', async () => {
    await assertFails(
      setDoc(
        userDocRef(authedDb(ALICE), ALICE),
        { migratedFromDiskAt: 'not-a-timestamp' },
      ),
    );
  });

  test('owner cannot delete their own user doc (locked)', async () => {
    await seedUserDoc(ALICE);
    await assertFails(deleteDoc(userDocRef(authedDb(ALICE), ALICE)));
  });
});

describe('users/{uid}/memories/{contactId} — anonymous denial', () => {
  test('anonymous read on another user’s memory is denied', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(getDoc(memoryDocRef(anonDb(), ALICE, 'sarah')));
  });

  test('anonymous list on another user’s memories collection is denied', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(getDocs(memoriesCollectionRef(anonDb(), ALICE)));
  });

  test('anonymous create is denied', async () => {
    await assertFails(
      setDoc(memoryDocRef(anonDb(), ALICE, 'sarah'), wellFormedMemory()),
    );
  });

  test('anonymous update is denied', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(
      setDoc(
        memoryDocRef(anonDb(), ALICE, 'sarah'),
        wellFormedMemory({ markdown: '# Sarah\n\nAnonymous edit.' }),
      ),
    );
  });

  test('anonymous delete is denied', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(deleteDoc(memoryDocRef(anonDb(), ALICE, 'sarah')));
  });
});

describe('users/{uid}/memories/{contactId} — shape validation', () => {
  test('create denied when markdown key is missing', async () => {
    const payload = wellFormedMemory();
    delete payload.markdown;
    await assertFails(
      setDoc(memoryDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when updatedAt key is missing', async () => {
    const payload = wellFormedMemory();
    delete payload.updatedAt;
    await assertFails(
      setDoc(memoryDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when schemaVersion key is missing', async () => {
    const payload = wellFormedMemory();
    delete payload.schemaVersion;
    await assertFails(
      setDoc(memoryDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when extra key is present', async () => {
    await assertFails(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ extra: 'not allowed' }),
      ),
    );
  });

  test('create denied when markdown is not a string', async () => {
    await assertFails(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ markdown: 12345 }),
      ),
    );
  });

  test('create denied when markdown exceeds 64KB cap (65537 bytes)', async () => {
    const oversized = 'x'.repeat(65537);
    await assertFails(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ markdown: oversized }),
      ),
    );
  });

  test('create allowed when markdown is exactly 65536 bytes', async () => {
    const atCap = 'x'.repeat(65536);
    await assertSucceeds(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ markdown: atCap }),
      ),
    );
  });

  test('create denied when schemaVersion is not an int', async () => {
    await assertFails(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ schemaVersion: '1' }),
      ),
    );
  });

  test('create denied when updatedAt is not a timestamp', async () => {
    await assertFails(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ updatedAt: '2026-05-24T00:00:00Z' }),
      ),
    );
  });

  test('update denied when payload introduces an extra field', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ extra: 'still not allowed' }),
      ),
    );
  });

  test('update denied when markdown exceeds 64KB cap on update', async () => {
    await seedMemory(ALICE, 'sarah');
    const oversized = 'x'.repeat(65537);
    await assertFails(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ markdown: oversized }),
      ),
    );
  });

  test('update denied when markdown is not a string', async () => {
    await seedMemory(ALICE, 'sarah');
    await assertFails(
      setDoc(
        memoryDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedMemory({ markdown: ['list', 'instead', 'of', 'string'] }),
      ),
    );
  });
});

describe('users/{uid}/connections/{contactId} — ownership', () => {
  test('owner can read own connection doc', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertSucceeds(
      getDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah')),
    );
  });

  test('owner can list own connections collection', async () => {
    await seedConnection(ALICE, 'sarah');
    await seedConnection(ALICE, 'mike');
    await assertSucceeds(
      getDocs(connectionsCollectionRef(authedDb(ALICE), ALICE)),
    );
  });

  test('owner can create well-formed own connection doc', async () => {
    await assertSucceeds(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection(),
      ),
    );
  });

  test('owner can update own connection doc with well-formed payload', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertSucceeds(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({
          name: 'Sarah Chen',
          bondScore: 88,
          nextStep: 'Schedule the next call',
        }),
      ),
    );
  });

  test('owner can delete own connection doc', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertSucceeds(
      deleteDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah')),
    );
  });

  test('other authenticated user cannot read another user’s connection doc', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      getDoc(connectionDocRef(authedDb(BOB), ALICE, 'sarah')),
    );
  });

  test('other authenticated user cannot list another user’s connections collection', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      getDocs(connectionsCollectionRef(authedDb(BOB), ALICE)),
    );
  });

  test('other authenticated user cannot create at another user’s connection path', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(BOB), ALICE, 'sarah'),
        wellFormedConnection(),
      ),
    );
  });

  test('other authenticated user cannot update another user’s connection doc', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(BOB), ALICE, 'sarah'),
        wellFormedConnection({ nextStep: 'Hijacked' }),
      ),
    );
  });

  test('other authenticated user cannot delete another user’s connection doc', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      deleteDoc(connectionDocRef(authedDb(BOB), ALICE, 'sarah')),
    );
  });
});

describe('users/{uid}/connections/{contactId} — anonymous denial', () => {
  test('anonymous read on another user’s connection is denied', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      getDoc(connectionDocRef(anonDb(), ALICE, 'sarah')),
    );
  });

  test('anonymous list on another user’s connections collection is denied', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      getDocs(connectionsCollectionRef(anonDb(), ALICE)),
    );
  });

  test('anonymous create is denied', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(anonDb(), ALICE, 'sarah'),
        wellFormedConnection(),
      ),
    );
  });

  test('anonymous update is denied', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      setDoc(
        connectionDocRef(anonDb(), ALICE, 'sarah'),
        wellFormedConnection({ nextStep: 'Anonymous edit.' }),
      ),
    );
  });

  test('anonymous delete is denied', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      deleteDoc(connectionDocRef(anonDb(), ALICE, 'sarah')),
    );
  });
});

describe('users/{uid}/connections/{contactId} — shape validation', () => {
  // ---- Required-field omissions -----------------------------------

  test('create denied when id is missing', async () => {
    const payload = wellFormedConnection();
    delete payload.id;
    await assertFails(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when name is missing', async () => {
    const payload = wellFormedConnection();
    delete payload.name;
    await assertFails(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when category is missing', async () => {
    const payload = wellFormedConnection();
    delete payload.category;
    await assertFails(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when bondScore is missing', async () => {
    const payload = wellFormedConnection();
    delete payload.bondScore;
    await assertFails(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when preferredChannels is missing', async () => {
    const payload = wellFormedConnection();
    delete payload.preferredChannels;
    await assertFails(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when schemaVersion is missing', async () => {
    const payload = wellFormedConnection();
    delete payload.schemaVersion;
    await assertFails(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  // ---- Unknown / extra field --------------------------------------

  test('create denied when extra unknown key is present', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ rogueField: 'not allowed' }),
      ),
    );
  });

  test('update denied when payload introduces an extra field', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ extra: 'still not allowed' }),
      ),
    );
  });

  // ---- bondScore range --------------------------------------------

  test('create denied when bondScore is below zero', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ bondScore: -1 }),
      ),
    );
  });

  test('create denied when bondScore is above one hundred', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ bondScore: 101 }),
      ),
    );
  });

  test('create allowed when bondScore is exactly zero', async () => {
    await assertSucceeds(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ bondScore: 0 }),
      ),
    );
  });

  test('create allowed when bondScore is exactly one hundred', async () => {
    await assertSucceeds(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ bondScore: 100 }),
      ),
    );
  });

  test('create denied when bondScore is not an int (string)', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ bondScore: '85' }),
      ),
    );
  });

  // ---- Wrong-type required fields ---------------------------------

  test('create denied when name is not a string', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ name: 12345 }),
      ),
    );
  });

  test('create denied when lastContact is not a timestamp', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ lastContact: '2026-05-20T00:00:00Z' }),
      ),
    );
  });

  test('create denied when knownSince is not a timestamp', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ knownSince: '2024-01-15' }),
      ),
    );
  });

  test('create denied when preferredChannels is not a list', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ preferredChannels: 'imessage' }),
      ),
    );
  });

  test('create denied when schemaVersion is not an int', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ schemaVersion: '1' }),
      ),
    );
  });

  test('create denied when updatedAt is not a timestamp', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ updatedAt: '2026-05-26T00:00:00Z' }),
      ),
    );
  });

  // ---- Optional fields: present-and-typed-or-absent ---------------

  test('create allowed when optional isSample is absent', async () => {
    const payload = wellFormedConnection();
    delete payload.isSample;
    await assertSucceeds(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when required email is absent (PRD §Q8: required-with-empty-string)', async () => {
    const payload = wellFormedConnection();
    delete payload.email;
    await assertFails(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create denied when required notes is absent (PRD §Q8: required-with-empty-string)', async () => {
    const payload = wellFormedConnection();
    delete payload.notes;
    await assertFails(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });

  test('create allowed when email and notes are empty strings (PRD §Q8)', async () => {
    await assertSucceeds(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ email: '', notes: '' }),
      ),
    );
  });

  test('create denied when email is wrong type', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ email: 12345 }),
      ),
    );
  });

  test('create denied when notes is wrong type', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ notes: ['array', 'instead'] }),
      ),
    );
  });

  test('create denied when isSample is wrong type', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ isSample: 'true' }),
      ),
    );
  });

  // ---- S4 (review fix): wrong-type matrix for remaining required strings

  test('create denied when id is not a string', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ id: 12345 }),
      ),
    );
  });

  test('create denied when category is not a string', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ category: 99 }),
      ),
    );
  });

  test('create denied when avatar is not a string', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ avatar: false }),
      ),
    );
  });

  test('create denied when nextStep is not a string', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ nextStep: 42 }),
      ),
    );
  });

  // ---- S3 (review fix): data.id must equal the {contactId} path ---

  test('create denied when data.id does not match the {contactId} path', async () => {
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ id: 'mike' }),
      ),
    );
  });

  test('update denied when data.id is mutated to a different value than {contactId}', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ id: 'mike', nextStep: 'Hijacked' }),
      ),
    );
  });

  test('create allowed when data.id matches the {contactId} path (explicit invariant)', async () => {
    await assertSucceeds(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ id: 'sarah' }),
      ),
    );
  });

  // ---- Update-time shape enforcement ------------------------------

  test('update denied when bondScore goes out of range', async () => {
    await seedConnection(ALICE, 'sarah');
    await assertFails(
      setDoc(
        connectionDocRef(authedDb(ALICE), ALICE, 'sarah'),
        wellFormedConnection({ bondScore: 250 }),
      ),
    );
  });

  test('update denied when required field is dropped', async () => {
    await seedConnection(ALICE, 'sarah');
    const payload = wellFormedConnection();
    delete payload.preferredChannels;
    await assertFails(
      setDoc(connectionDocRef(authedDb(ALICE), ALICE, 'sarah'), payload),
    );
  });
});

describe('users/{uid}/interactions/{interactionId} — ownership', () => {
  test('owner can read own interaction doc', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertSucceeds(
      getDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1')),
    );
  });

  test('owner can list own interactions collection', async () => {
    await seedInteraction(ALICE, 'i-1');
    await seedInteraction(ALICE, 'i-2');
    await assertSucceeds(
      getDocs(interactionsCollectionRef(authedDb(ALICE), ALICE)),
    );
  });

  test('owner can create well-formed own interaction doc', async () => {
    await assertSucceeds(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction(),
      ),
    );
  });

  test('owner can update own interaction doc with well-formed payload', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertSucceeds(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({
          title: 'Coffee chat',
          note: 'Updated note',
        }),
      ),
    );
  });

  test('owner can delete own interaction doc', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertSucceeds(
      deleteDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1')),
    );
  });

  test('other authenticated user cannot read another user’s interaction doc', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      getDoc(interactionDocRef(authedDb(BOB), ALICE, 'i-1')),
    );
  });

  test('other authenticated user cannot list another user’s interactions collection', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      getDocs(interactionsCollectionRef(authedDb(BOB), ALICE)),
    );
  });

  test('other authenticated user cannot create at another user’s interaction path', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(BOB), ALICE, 'i-1'),
        wellFormedInteraction(),
      ),
    );
  });

  test('other authenticated user cannot update another user’s interaction doc', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(BOB), ALICE, 'i-1'),
        wellFormedInteraction({ note: 'Hijacked' }),
      ),
    );
  });

  test('other authenticated user cannot delete another user’s interaction doc', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      deleteDoc(interactionDocRef(authedDb(BOB), ALICE, 'i-1')),
    );
  });
});

describe('users/{uid}/interactions/{interactionId} — anonymous denial', () => {
  test('anonymous read on another user’s interaction is denied', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      getDoc(interactionDocRef(anonDb(), ALICE, 'i-1')),
    );
  });

  test('anonymous list is denied', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      getDocs(interactionsCollectionRef(anonDb(), ALICE)),
    );
  });

  test('anonymous create is denied', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(anonDb(), ALICE, 'i-1'),
        wellFormedInteraction(),
      ),
    );
  });

  test('anonymous update is denied', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      setDoc(
        interactionDocRef(anonDb(), ALICE, 'i-1'),
        wellFormedInteraction({ note: 'Anon edit' }),
      ),
    );
  });

  test('anonymous delete is denied', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      deleteDoc(interactionDocRef(anonDb(), ALICE, 'i-1')),
    );
  });
});

describe('users/{uid}/interactions/{interactionId} — shape validation', () => {
  // ---- Required-field omissions -----------------------------------

  test('create denied when id is missing', async () => {
    const payload = wellFormedInteraction();
    delete payload.id;
    await assertFails(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });

  test('create denied when contactId is missing', async () => {
    const payload = wellFormedInteraction();
    delete payload.contactId;
    await assertFails(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });

  test('create denied when type is missing', async () => {
    const payload = wellFormedInteraction();
    delete payload.type;
    await assertFails(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });

  test('create denied when title is missing (PRD §Q8: required-with-empty-string)', async () => {
    const payload = wellFormedInteraction();
    delete payload.title;
    await assertFails(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });

  test('create denied when note is missing (PRD §Q8: required-with-empty-string)', async () => {
    const payload = wellFormedInteraction();
    delete payload.note;
    await assertFails(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });

  test('create denied when date is missing', async () => {
    const payload = wellFormedInteraction();
    delete payload.date;
    await assertFails(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });

  test('create denied when schemaVersion is missing', async () => {
    const payload = wellFormedInteraction();
    delete payload.schemaVersion;
    await assertFails(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });

  test('create allowed when title and note are empty strings (PRD §Q8)', async () => {
    await assertSucceeds(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ title: '', note: '' }),
      ),
    );
  });

  // ---- Unknown / extra field --------------------------------------

  test('create denied when extra unknown key is present', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ rogueField: 'not allowed' }),
      ),
    );
  });

  test('update denied when payload introduces an extra field', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ extra: 'still not allowed' }),
      ),
    );
  });

  // ---- type enum validation ---------------------------------------

  test('create allowed for every InteractionType enum value', async () => {
    for (const t of [
      'interaction',
      'personalDetail',
      'preference',
      'reminder',
      'sharedActivity',
      'relationshipNote',
    ]) {
      await assertSucceeds(
        setDoc(
          interactionDocRef(authedDb(ALICE), ALICE, `i-${t}`),
          wellFormedInteraction({ id: `i-${t}`, type: t }),
        ),
      );
    }
  });

  test('create denied when type is not in the InteractionType enum set', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ type: 'gossip' }),
      ),
    );
  });

  test('create denied when type is the wrong primitive (int)', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ type: 7 }),
      ),
    );
  });

  // ---- source enum validation -------------------------------------

  test('create allowed when source is omitted (genuinely optional)', async () => {
    const payload = wellFormedInteraction();
    delete payload.source;
    await assertSucceeds(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });

  test('create allowed for every InteractionSource enum value', async () => {
    for (const s of ['manual', 'aiSuggested']) {
      await assertSucceeds(
        setDoc(
          interactionDocRef(authedDb(ALICE), ALICE, `i-${s}`),
          wellFormedInteraction({ id: `i-${s}`, source: s }),
        ),
      );
    }
  });

  test('create denied when source is not in the InteractionSource enum set', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ source: 'imported' }),
      ),
    );
  });

  // ---- attachments optional + type guard --------------------------

  test('create allowed when attachments is omitted (genuinely optional)', async () => {
    const payload = wellFormedInteraction();
    delete payload.attachments;
    await assertSucceeds(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });

  test('create denied when attachments is the wrong primitive (string)', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ attachments: 'note.md' }),
      ),
    );
  });

  // ---- Wrong-type required fields ---------------------------------

  test('create denied when id is not a string', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ id: 12345 }),
      ),
    );
  });

  test('create denied when contactId is not a string', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ contactId: 99 }),
      ),
    );
  });

  test('create denied when title is not a string', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ title: 42 }),
      ),
    );
  });

  test('create denied when note is not a string', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ note: ['array'] }),
      ),
    );
  });

  test('create denied when date is not a timestamp', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ date: '2026-05-20' }),
      ),
    );
  });

  test('create denied when schemaVersion is not an int', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ schemaVersion: '1' }),
      ),
    );
  });

  test('create denied when updatedAt is not a timestamp', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ updatedAt: '2026-05-26T00:00:00Z' }),
      ),
    );
  });

  // ---- data.id must equal the {interactionId} path ----------------

  test('create denied when data.id does not match the {interactionId} path', async () => {
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ id: 'i-other' }),
      ),
    );
  });

  test('update denied when data.id is mutated to a different value', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ id: 'i-other', note: 'Hijacked' }),
      ),
    );
  });

  test('create allowed when data.id matches the path (explicit invariant)', async () => {
    await assertSucceeds(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ id: 'i-1' }),
      ),
    );
  });

  // ---- Update-time shape enforcement ------------------------------

  test('update denied when type is invalid', async () => {
    await seedInteraction(ALICE, 'i-1');
    await assertFails(
      setDoc(
        interactionDocRef(authedDb(ALICE), ALICE, 'i-1'),
        wellFormedInteraction({ type: 'gossip' }),
      ),
    );
  });

  test('update denied when required field is dropped', async () => {
    await seedInteraction(ALICE, 'i-1');
    const payload = wellFormedInteraction();
    delete payload.title;
    await assertFails(
      setDoc(interactionDocRef(authedDb(ALICE), ALICE, 'i-1'), payload),
    );
  });
});
