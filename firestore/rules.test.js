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
