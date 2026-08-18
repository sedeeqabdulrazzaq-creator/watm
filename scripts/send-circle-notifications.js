#!/usr/bin/env node
/**
 * Pushes an FCM notification for two kinds of "live" circle activity that
 * flutter_local_notifications can never react to on its own — it only fires
 * reminders scheduled ahead of time on the same device, not something that
 * just happened on the server while the app was closed:
 *
 *   - A new member joins a circle -> notify the other current members.
 *   - Someone sends an encouragement -> notify the recipient.
 *
 * Runs the same "no Cloud Functions, no Blaze plan" way as
 * cleanup-orphaned-members.js: a plain Node script with the Admin SDK,
 * triggered on a schedule by GitHub Actions instead of a Firestore trigger.
 * That means polling instead of an instant push — a few minutes of lag,
 * per the workflow's schedule — and a cursor stored in Firestore
 * (system/notificationWorkerState) instead of a Cloud Functions trigger's
 * automatic "only fires once" guarantee.
 *
 * Usage (PowerShell, from the `watm` project folder):
 *   cd scripts
 *   npm install
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccountKey.json"
 *   node send-circle-notifications.js             # sends for real
 *   node send-circle-notifications.js --dry-run    # prints only, cursor
 *                                                   # is not advanced
 *
 * The service account key comes from Firebase Console -> Project settings
 * -> Service accounts -> Generate new private key. Keep that file out of
 * version control.
 */

const admin = require('firebase-admin');

const DRY_RUN = process.argv.includes('--dry-run');
const CURSOR_DOC_PATH = 'system/notificationWorkerState';

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();
const messaging = admin.messaging();

async function loadCursor() {
  const snap = await db.doc(CURSOR_DOC_PATH).get();
  if (snap.exists) {
    const data = snap.data();
    return {
      lastMemberJoinCheckAt: data.lastMemberJoinCheckAt,
      lastEncouragementCheckAt: data.lastEncouragementCheckAt,
      isFirstRun: false,
    };
  }
  // No cursor yet: bootstrap to "now" so the very first run doesn't
  // suddenly notify everyone about every member/encouragement that ever
  // existed. Nothing is sent this run either way.
  const now = admin.firestore.Timestamp.now();
  return {
    lastMemberJoinCheckAt: now,
    lastEncouragementCheckAt: now,
    isFirstRun: true,
  };
}

async function saveCursor(runStartedAt) {
  if (DRY_RUN) return;
  await db.doc(CURSOR_DOC_PATH).set(
    {
      lastMemberJoinCheckAt: runStartedAt,
      lastEncouragementCheckAt: runStartedAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

/** Sends one notification; clears a dead token instead of retrying it forever. */
async function sendToUser(userId, { title, body, data }) {
  const userSnap = await db.collection('users').doc(userId).get();
  const token = userSnap.data()?.fcmToken;
  if (!token) return false;

  console.log(`  -> notify ${userId}: "${title}" / "${body}"`);
  if (DRY_RUN) return true;

  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data ?? {}).map(([key, value]) => [key, String(value)]),
      ),
    });
    return true;
  } catch (error) {
    if (error.code === 'messaging/registration-token-not-registered') {
      await db
        .collection('users')
        .doc(userId)
        .update({ fcmToken: admin.firestore.FieldValue.delete() });
      console.log(`  (cleared dead token for ${userId})`);
    } else {
      console.error(`  failed to notify ${userId}:`, error.message);
    }
    return false;
  }
}

async function notifyNewMembers(cursor, runStartedAt) {
  const groupsSnap = await db.collection('groups').get();
  let notified = 0;

  for (const groupDoc of groupsSnap.docs) {
    const newMembersSnap = await groupDoc.ref
      .collection('members')
      .where('joinedAt', '>', cursor.lastMemberJoinCheckAt)
      .where('joinedAt', '<=', runStartedAt)
      .get();
    if (newMembersSnap.empty) continue;

    const allMembersSnap = await groupDoc.ref.collection('members').get();

    for (const newMemberDoc of newMembersSnap.docs) {
      const newMemberName = newMemberDoc.data().firstName || 'عضو جديد';
      console.log(`Group ${groupDoc.id}: new member ${newMemberDoc.id} (${newMemberName})`);

      for (const memberDoc of allMembersSnap.docs) {
        if (memberDoc.id === newMemberDoc.id) continue; // don't notify the joiner about themselves
        const sent = await sendToUser(memberDoc.id, {
          title: 'دائرتك تكبر',
          body: `${newMemberName} انضم إلى دائرتك.`,
          data: { type: 'member_joined', groupId: groupDoc.id },
        });
        if (sent) notified += 1;
      }
    }
  }

  return notified;
}

async function notifyEncouragements(cursor, runStartedAt) {
  const groupsSnap = await db.collection('groups').get();
  let notified = 0;

  for (const groupDoc of groupsSnap.docs) {
    const newEncouragementsSnap = await groupDoc.ref
      .collection('encouragements')
      .where('createdAt', '>', cursor.lastEncouragementCheckAt)
      .where('createdAt', '<=', runStartedAt)
      .get();
    if (newEncouragementsSnap.empty) continue;

    for (const doc of newEncouragementsSnap.docs) {
      const { senderName, recipientId, message } = doc.data();
      console.log(`Group ${groupDoc.id}: encouragement ${doc.id} from ${senderName} to ${recipientId}`);
      const sent = await sendToUser(recipientId, {
        title: `تشجيع من ${senderName || 'أحد أعضاء دائرتك'}`,
        body: message || '',
        data: { type: 'encouragement', groupId: groupDoc.id, encouragementId: doc.id },
      });
      if (sent) notified += 1;
    }
  }

  return notified;
}

async function main() {
  console.log(DRY_RUN ? 'Running in DRY RUN mode — nothing will be sent, cursor will not move.' : 'Running for real.');

  const runStartedAt = admin.firestore.Timestamp.now();
  const cursor = await loadCursor();
  if (cursor.isFirstRun) {
    console.log('No cursor found — bootstrapping to now. Nothing to send on this run.');
    await saveCursor(runStartedAt);
    return;
  }

  const memberNotifications = await notifyNewMembers(cursor, runStartedAt);
  const encouragementNotifications = await notifyEncouragements(cursor, runStartedAt);

  await saveCursor(runStartedAt);

  console.log('---');
  console.log(`Member-join notifications sent: ${memberNotifications}`);
  console.log(`Encouragement notifications sent: ${encouragementNotifications}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
