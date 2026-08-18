const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

// Mirrors lib/core/utils/circle_settings.dart. Keep these two in sync if the
// Flutter app's constants ever change.
const MAX_MEMBERS = 7;
const MIN_START_MEMBERS = 5;

function statusForMemberCount(count) {
  if (count >= MAX_MEMBERS) return 'full';
  if (count >= MIN_START_MEMBERS) return 'active';
  return 'forming';
}

/**
 * Deleting a user from Firebase Authentication only removes their sign-in
 * credential — it does not touch any Firestore data. Without this trigger,
 * a deleted account's user doc and circle membership stay in Firestore
 * forever, so the circle keeps counting and displaying a member who can no
 * longer sign in.
 *
 * This runs with admin privileges and bypasses firestore.rules, so it can
 * clean up the private `users/{uid}` doc as well as the membership doc,
 * which a client can never delete directly.
 */
exports.cleanupUserOnDelete = functions.auth.user().onDelete(async (user) => {
  const db = admin.firestore();
  const uid = user.uid;
  const userRef = db.collection('users').doc(uid);

  const userSnap = await userRef.get();
  const userData = userSnap.data() || {};
  const groupId = userData.groupId || userData.circleId || '';

  if (groupId) {
    const groupRef = db.collection('groups').doc(groupId);
    const memberRef = groupRef.collection('members').doc(uid);

    await db.runTransaction(async (tx) => {
      // -- reads first --
      const memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) return;

      const groupSnap = await tx.get(groupRef);
      if (!groupSnap.exists) {
        tx.delete(memberRef);
        return;
      }

      const groupData = groupSnap.data() || {};
      const currentCount = Number(groupData.memberCount) || 0;
      const newCount = Math.max(currentCount - 1, 0);
      const newStatus = statusForMemberCount(newCount);
      const matchingKey = groupData.matchingKey;

      // If this circle now has a free slot, reopen it in the matching
      // bucket so a new member can be routed into it instead of always
      // starting a brand new circle.
      let bucketRef = null;
      let bucketHasOpenGroup = false;
      let bucketPointsHere = false;
      if (matchingKey && newCount < MAX_MEMBERS) {
        bucketRef = db.collection('matchingBuckets').doc(matchingKey);
        const bucketSnap = await tx.get(bucketRef);
        const openGroupId = (bucketSnap.data() || {}).openGroupId;
        bucketHasOpenGroup = Boolean(openGroupId);
        bucketPointsHere = openGroupId === groupId;
      }

      // -- writes after all reads --
      tx.delete(memberRef);

      if (newCount <= 0) {
        // آخر عضو غادر. إبقاء الدائرة بعدّاد صفر يخالف قواعد الأمان
        // (تشترط memberCount >= 1 لحالة forming) ويجعل الحاوية توجّه
        // المستخدمين الجدد إلى دائرة شبح. نحذفها ونفرّغ إشارة الحاوية.
        tx.delete(groupRef);
        if (bucketRef && bucketPointsHere) {
          tx.set(
            bucketRef,
            {
              matchingKey,
              openGroupId: admin.firestore.FieldValue.delete(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }
        return;
      }

      tx.update(groupRef, {
        memberCount: newCount,
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      if (bucketRef && !bucketHasOpenGroup) {
        tx.set(
          bucketRef,
          {
            matchingKey,
            openGroupId: groupId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    });
  }

  await Promise.all([
    db.collection('matchingQueue').doc(uid).delete().catch(() => {}),
    // recursiveDelete removes the user doc AND every subcollection under it
    // (checkIns, returns, notificationReads, weeklyReviews, scheduleItems).
    // A plain userRef.delete() only removes the parent doc and would leave
    // those subcollections orphaned in Firestore forever.
    db.recursiveDelete(userRef).catch(() => {}),
  ]);
});
