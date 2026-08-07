#!/usr/bin/env node
/**
 * One-time cleanup for accounts that were deleted from Firebase
 * Authentication *before* the `cleanupUserOnDelete` Cloud Function existed.
 * Deleting a user from the Authentication console never touches Firestore,
 * so their `users/{uid}` doc and their `groups/{groupId}/members/{uid}`
 * membership stay behind forever unless something removes them — this
 * script finds and removes them.
 *
 * Safe by default: this is a DRY RUN unless you pass --apply. Always run
 * once without --apply first and read the output before applying.
 *
 * Usage (PowerShell, from the `watm` project folder):
 *   cd scripts
 *   npm install
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccountKey.json"
 *   node cleanup-orphaned-members.js            # dry run — prints only
 *   node cleanup-orphaned-members.js --apply     # actually deletes
 *
 * The service account key comes from Firebase Console -> Project settings
 * -> Service accounts -> Generate new private key. Keep that file out of
 * version control.
 */

const admin = require('firebase-admin');

const APPLY = process.argv.includes('--apply');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();
const auth = admin.auth();

// Mirrors lib/core/utils/circle_settings.dart and functions/index.js.
const MAX_MEMBERS = 7;
const MIN_START_MEMBERS = 5;

function statusForMemberCount(count) {
  if (count >= MAX_MEMBERS) return 'full';
  if (count >= MIN_START_MEMBERS) return 'active';
  return 'forming';
}

async function loadAllAuthUids() {
  const uids = new Set();
  let pageToken;
  do {
    const result = await auth.listUsers(1000, pageToken);
    result.users.forEach((u) => uids.add(u.uid));
    pageToken = result.pageToken;
  } while (pageToken);
  return uids;
}

async function cleanupGroupMembers(existingUids) {
  const groupsSnap = await db.collection('groups').get();
  let ghostCount = 0;

  for (const groupDoc of groupsSnap.docs) {
    const membersSnap = await groupDoc.ref.collection('members').get();
    const ghosts = membersSnap.docs.filter((m) => !existingUids.has(m.id));
    if (ghosts.length === 0) continue;

    console.log(
      `Group ${groupDoc.id}: ${ghosts.length} ghost member(s) -> ${ghosts
        .map((g) => g.id)
        .join(', ')}`,
    );
    ghostCount += ghosts.length;

    if (!APPLY) continue;

    await db.runTransaction(async (tx) => {
      const groupSnap = await tx.get(groupDoc.ref);
      if (!groupSnap.exists) return;
      const currentCount = Number(groupSnap.data().memberCount) || 0;
      const newCount = Math.max(currentCount - ghosts.length, 0);
      const newStatus = statusForMemberCount(newCount);

      ghosts.forEach((g) => tx.delete(g.ref));
      tx.update(groupDoc.ref, {
        memberCount: newCount,
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  }

  return ghostCount;
}

async function cleanupOrphanedUserDocs(existingUids) {
  const usersSnap = await db.collection('users').get();
  const orphans = usersSnap.docs.filter((u) => !existingUids.has(u.id));

  if (orphans.length > 0) {
    console.log(
      `users collection: ${orphans.length} orphaned doc(s) -> ${orphans
        .map((o) => o.id)
        .join(', ')}`,
    );
  }

  if (!APPLY) return orphans.length;

  const batchSize = 400; // stay under Firestore's 500-write batch limit
  for (let i = 0; i < orphans.length; i += batchSize) {
    const batch = db.batch();
    orphans.slice(i, i + batchSize).forEach((o) => batch.delete(o.ref));
    await batch.commit();
  }
  return orphans.length;
}

async function main() {
  console.log(
    APPLY
      ? 'Running in APPLY mode — changes will be made.'
      : 'Running in DRY RUN mode — no changes will be made. Pass --apply to actually delete.',
  );

  const existingUids = await loadAllAuthUids();
  console.log(`Loaded ${existingUids.size} real Authentication account(s).`);

  const ghostMembers = await cleanupGroupMembers(existingUids);
  const orphanUsers = await cleanupOrphanedUserDocs(existingUids);

  console.log('---');
  console.log(`Ghost circle members found: ${ghostMembers}`);
  console.log(`Orphaned user docs found: ${orphanUsers}`);
  if (!APPLY) {
    console.log('Nothing was deleted. Re-run with --apply to actually clean up.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
