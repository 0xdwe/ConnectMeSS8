const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, deleteObject, getBytes, listAll } = require('firebase/storage');

const PROJECT_ID = 'connect-me-rules-test';
const ALICE = 'alice-uid';
const BOB = 'bob-uid';

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

afterAll(async () => {
  if (testEnv) await testEnv.cleanup();
});

function authedStorage(uid) {
  return testEnv.authenticatedContext(uid).storage();
}

function anonStorage() {
  return testEnv.unauthenticatedContext().storage();
}

function avatarRef(storage, uid) {
  return ref(storage, `users/${uid}/profile/avatar.jpg`);
}

function siblingRef(storage, uid) {
  return ref(storage, `users/${uid}/profile/banner.jpg`);
}

function imageBytes(size = 3) {
  return new Uint8Array(size).fill(1);
}

describe('profile avatar storage rules', () => {
  test('owner can upload image avatar', async () => {
    await assertSucceeds(
      uploadBytes(avatarRef(authedStorage(ALICE), ALICE), imageBytes(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('anonymous upload is denied', async () => {
    await assertFails(
      uploadBytes(avatarRef(anonStorage(), ALICE), imageBytes(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('cross-user upload is denied', async () => {
    await assertFails(
      uploadBytes(avatarRef(authedStorage(BOB), ALICE), imageBytes(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('non-image upload is denied', async () => {
    await assertFails(
      uploadBytes(avatarRef(authedStorage(ALICE), ALICE), imageBytes(), {
        contentType: 'text/plain',
      }),
    );
  });

  test('oversized upload is denied', async () => {
    await assertFails(
      uploadBytes(avatarRef(authedStorage(ALICE), ALICE), imageBytes(2 * 1024 * 1024 + 1), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('owner can read and delete own avatar', async () => {
    const storage = authedStorage(ALICE);
    const objectRef = avatarRef(storage, ALICE);
    await assertSucceeds(uploadBytes(objectRef, imageBytes(), { contentType: 'image/png' }));
    await assertSucceeds(getBytes(objectRef));
    await assertSucceeds(deleteObject(objectRef));
  });

  test('cross-user read and delete are denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(avatarRef(ctx.storage(), ALICE), imageBytes(), { contentType: 'image/png' });
    });

    await assertFails(getBytes(avatarRef(authedStorage(BOB), ALICE)));
    await assertFails(deleteObject(avatarRef(authedStorage(BOB), ALICE)));
  });

  test('anonymous read and delete are denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(avatarRef(ctx.storage(), ALICE), imageBytes(), { contentType: 'image/png' });
    });

    await assertFails(getBytes(avatarRef(anonStorage(), ALICE)));
    await assertFails(deleteObject(avatarRef(anonStorage(), ALICE)));
  });

  test('sibling paths and listing are denied', async () => {
    const storage = authedStorage(ALICE);
    await assertFails(uploadBytes(siblingRef(storage, ALICE), imageBytes(), { contentType: 'image/png' }));
    await assertFails(listAll(ref(storage, `users/${ALICE}/profile`)));
  });
});
