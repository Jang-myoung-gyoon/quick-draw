"use strict";

const admin = require("firebase-admin");
const {HttpsError, onCall} = require("firebase-functions/v2/https");

admin.initializeApp();

const db = admin.database();
const firestore = admin.firestore();

const region = "us-central1";
const refreshIntervalMillis = 20 * 60 * 1000;
const maxRankingFriends = 100;
const maxScoreRecords = 50;
const maxCommunityFriends = 200;
const maxFriendRequests = 100;
const allowedOrigins = [
  "http://localhost",
  /^http:\/\/localhost(:\d+)?$/,
  "http://127.0.0.1",
  /^http:\/\/127\.0\.0\.1(:\d+)?$/,
  "https://quick-draw-aaceb.web.app",
  "https://quick-draw-aaceb.firebaseapp.com",
];
const callableOptions = {region, cors: allowedOrigins};

exports.loadProgress = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const snapshot = await db.ref(`users/${uid}/progress`).get();
  return {progress: snapshot.exists() ? snapshot.val() : null};
});

exports.saveProgress = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const progress = readProgress(request.data?.progress);
  const displayName = readOptionalString(request.data?.displayName, 80);
  const now = Date.now();

  await db.ref(`users/${uid}/progress`).set({
    ...progress,
    updatedAt: admin.database.ServerValue.TIMESTAMP,
  });
  await updateRanking(uid, {
    achievementScore: achievementScore(progress),
    stageLevel: progress.bestStageLevel,
    characterLevel: progress.bestCharacterLevel,
    updatedAtMillis: now,
    displayName,
  });

  return {ok: true};
});

exports.recordScore = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const record = readScoreRecord(request.data?.record);
  const displayName =
    readOptionalString(request.data?.displayName, 80) ?? record.playerName;
  const achievement = clampInt(request.data?.achievementScore, 0, 999999999);
  const playedAtMillis = record.playedAtMillis || Date.now();
  const scoreRecord = {
    score: record.score,
    stageLevel: record.stageLevel,
    characterLevel: record.characterLevel,
    playedAtMillis,
    achievementScore: achievement,
    uid,
    ...(displayName ? {playerName: displayName} : {}),
  };
  const key = `${playedAtMillis}_${uid}_${record.score}`;

  await db.ref(`users/${uid}/scores/${key}`).set({
    ...scoreRecord,
    updatedAt: admin.database.ServerValue.TIMESTAMP,
  });
  await Promise.all([
    trimScoreRecords(uid),
    updateRanking(uid, {
      score: record.score,
      achievementScore: achievement,
      stageLevel: record.stageLevel,
      characterLevel: record.characterLevel,
      updatedAtMillis: playedAtMillis,
      displayName,
    }),
  ]);

  return {ok: true};
});

exports.sendFriendRequest = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const friendUid = readRequiredString(request.data?.friendUid, "friendUid", 128);
  if (friendUid === uid) {
    throw new HttpsError("invalid-argument", "Cannot add yourself as a friend.");
  }

  const [currentUser, friendUser] = await Promise.all([
    admin.auth().getUser(uid),
    loadAuthUser(friendUid),
  ]);
  if (!friendUser) {
    throw new HttpsError("not-found", "Friend user was not found.");
  }

  const existingFriend = await db.ref(`friends/${uid}/${friendUid}`).get();
  if (existingFriend.exists()) {
    return {ok: true, alreadyFriends: true};
  }
  const existingRequest = await db.ref(`friendRequests/${friendUid}/incoming/${uid}`).get();
  if (existingRequest.exists()) {
    return {ok: true, alreadyRequested: true};
  }

  const [incomingCount, outgoingCount] = await Promise.all([
    countChildren(`friendRequests/${friendUid}/incoming`),
    countChildren(`friendRequests/${uid}/outgoing`),
  ]);
  if (incomingCount >= maxFriendRequests || outgoingCount >= maxFriendRequests) {
    throw new HttpsError("resource-exhausted", "Friend request limit reached.");
  }

  const now = Date.now();
  const requestData = communityUserRecord(uid, currentUser, now);
  const outgoingData = communityUserRecord(friendUid, friendUser, now);
  const updates = {};
  updates[`friendRequests/${friendUid}/incoming/${uid}`] = requestData;
  updates[`friendRequests/${uid}/outgoing/${friendUid}`] = outgoingData;
  await db.ref().update(updates);

  return {ok: true};
});

exports.acceptFriendRequest = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const requesterUid = readRequiredString(
    request.data?.requesterUid,
    "requesterUid",
    128,
  );
  if (requesterUid === uid) {
    throw new HttpsError("invalid-argument", "Cannot accept yourself.");
  }

  const incoming = await db.ref(`friendRequests/${uid}/incoming/${requesterUid}`).get();
  if (!incoming.exists()) {
    throw new HttpsError("not-found", "Friend request was not found.");
  }

  const [currentUser, requesterUser] = await Promise.all([
    admin.auth().getUser(uid),
    loadAuthUser(requesterUid),
  ]);
  if (!requesterUser) {
    throw new HttpsError("not-found", "Requester user was not found.");
  }

  const now = Date.now();
  const updates = {};
  updates[`friends/${uid}/${requesterUid}`] = communityUserRecord(
    requesterUid,
    requesterUser,
    now,
  );
  updates[`friends/${requesterUid}/${uid}`] = communityUserRecord(
    uid,
    currentUser,
    now,
  );
  updates[`friendRequests/${uid}/incoming/${requesterUid}`] = null;
  updates[`friendRequests/${requesterUid}/outgoing/${uid}`] = null;
  updates[`rankingRefreshes/${uid}`] = null;
  updates[`rankingRefreshes/${requesterUid}`] = null;
  await db.ref().update(updates);

  return {ok: true};
});

exports.loadCommunity = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const [friends, incomingRequests, outgoingRequests] = await Promise.all([
    loadCommunityUsers(`friends/${uid}`),
    loadCommunityUsers(`friendRequests/${uid}/incoming`, maxFriendRequests),
    loadCommunityUsers(`friendRequests/${uid}/outgoing`, maxFriendRequests),
  ]);

  return {
    uid,
    friends,
    incomingRequests,
    outgoingRequests,
  };
});

exports.loadFriendRanking = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const now = Date.now();
  const refreshRef = db.ref(`rankingRefreshes/${uid}`);
  const refreshSnapshot = await refreshRef.get();
  const lastRefresh = readInt(refreshSnapshot.val()?.lastAt, 0);

  if (lastRefresh > 0 && now - lastRefresh < refreshIntervalMillis) {
    const cache = await db.ref(`rankingCaches/${uid}`).get();
    if (cache.exists()) {
      return {
        ...cache.val(),
        refreshedAtMillis: lastRefresh,
        refreshLimited: true,
      };
    }
  }

  const friendUids = await loadFriendUids(uid);
  const entries = await loadRankingEntries(uid, friendUids);
  const response = {
    entries,
    refreshedAtMillis: now,
    refreshLimited: false,
  };

  await Promise.all([
    refreshRef.set({
      lastAt: now,
      updatedAt: admin.database.ServerValue.TIMESTAMP,
    }),
    db.ref(`rankingCaches/${uid}`).set({
      ...response,
      updatedAt: admin.database.ServerValue.TIMESTAMP,
    }),
  ]);

  return response;
});

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid;
}

function readProgress(value) {
  if (!isPlainObject(value)) {
    throw new HttpsError("invalid-argument", "progress must be an object.");
  }
  return {
    bestStageLevel: clampInt(value.bestStageLevel, 1, 9999),
    bestCharacterLevel: clampInt(value.bestCharacterLevel, 1, 9999),
    bestScore: clampInt(value.bestScore, 0, 999999999),
    selectedUpgrades: readStringArray(value.selectedUpgrades, 200),
    maxedUpgrades: readStringArray(value.maxedUpgrades, 200),
    acknowledgedAchievements: readStringArray(
      value.acknowledgedAchievements,
      500,
    ),
    tutorialCompleted: value.tutorialCompleted === true,
    schemaVersion: 1,
  };
}

function readScoreRecord(value) {
  if (!isPlainObject(value)) {
    throw new HttpsError("invalid-argument", "record must be an object.");
  }
  return {
    score: clampInt(value.score, 0, 999999999),
    stageLevel: clampInt(value.stageLevel, 1, 9999),
    characterLevel: clampInt(value.characterLevel, 1, 9999),
    playedAtMillis: clampInt(value.playedAtMillis, 0, 9999999999999),
    playerName: readOptionalString(value.playerName, 80),
  };
}

async function updateRanking(uid, next) {
  const ref = firestore.collection("rankings").doc(uid);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const previous = snapshot.exists ? snapshot.data() : {};
    const previousScore = readInt(previous.score, 0);
    const nextScore =
      typeof next.score === "number" ? Math.max(previousScore, next.score) : previousScore;
    const previousAchievement = readInt(previous.achievementScore, 0);
    const nextAchievement = Math.max(
      previousAchievement,
      readInt(next.achievementScore, 0),
    );

    transaction.set(ref, {
      score: nextScore,
      achievementScore: nextAchievement,
      stageLevel: Math.max(readInt(previous.stageLevel, 1), readInt(next.stageLevel, 1)),
      characterLevel: Math.max(
        readInt(previous.characterLevel, 1),
        readInt(next.characterLevel, 1),
      ),
      updatedAtMillis: Math.max(
        readInt(previous.updatedAtMillis, 0),
        readInt(next.updatedAtMillis, Date.now()),
      ),
      ...(next.displayName ? {displayName: next.displayName} : {}),
    }, {merge: true});
  });
}

async function loadFriendUids(uid) {
  const snapshot = await db.ref(`friends/${uid}`).get();
  const uids = new Set([uid]);
  const value = snapshot.val();
  if (isPlainObject(value)) {
    for (const friendUid of Object.keys(value)) {
      if (uids.size >= maxRankingFriends + 1) {
        break;
      }
      if (friendUid && friendUid.length <= 128) {
        uids.add(friendUid);
      }
    }
  }
  return [...uids];
}

async function loadCommunityUsers(path, maxItems = maxCommunityFriends) {
  const snapshot = await db.ref(path).limitToFirst(maxItems).get();
  const users = [];
  snapshot.forEach((child) => {
    const value = child.val();
    users.push({
      uid: readOptionalString(value?.uid, 128) ?? child.key,
      displayName: readOptionalString(value?.displayName, 80),
      updatedAtMillis: readInt(value?.updatedAtMillis, 0),
    });
  });
  return users;
}

async function countChildren(path) {
  const snapshot = await db.ref(path).get();
  let count = 0;
  snapshot.forEach(() => {
    count += 1;
  });
  return count;
}

async function loadAuthUser(uid) {
  try {
    return await admin.auth().getUser(uid);
  } catch (_) {
    return null;
  }
}

function communityUserRecord(uid, user, now) {
  return {
    uid,
    updatedAtMillis: now,
    ...(user.displayName ? {displayName: user.displayName.slice(0, 80)} : {}),
  };
}

async function loadRankingEntries(currentUid, uids) {
  const snapshots = await Promise.all(
    uids.map((uid) => firestore.collection("rankings").doc(uid).get()),
  );
  return snapshots.map((snapshot, index) => {
    const uid = uids[index];
    const data = snapshot.exists ? snapshot.data() : {};
    return {
      uid,
      displayName: readOptionalString(data.displayName, 80),
      score: readInt(data.score, 0),
      achievementScore: readInt(data.achievementScore, 0),
      stageLevel: readInt(data.stageLevel, 1),
      characterLevel: readInt(data.characterLevel, 1),
      updatedAtMillis: readInt(data.updatedAtMillis, 0),
      isCurrentUser: uid === currentUid,
    };
  });
}

async function trimScoreRecords(uid) {
  const snapshot = await db
    .ref(`users/${uid}/scores`)
    .orderByChild("playedAtMillis")
    .limitToFirst(maxScoreRecords + 1)
    .get();
  const keys = [];
  snapshot.forEach((child) => {
    keys.push(child.key);
  });
  if (keys.length <= maxScoreRecords) {
    return;
  }
  const removals = {};
  for (const key of keys.slice(0, keys.length - maxScoreRecords)) {
    removals[key] = null;
  }
  await db.ref(`users/${uid}/scores`).update(removals);
}

function achievementScore(progress) {
  return (
    progress.acknowledgedAchievements.length * 100 +
    progress.selectedUpgrades.length * 100 +
    progress.maxedUpgrades.length * 100 +
    Math.max(0, progress.bestStageLevel - 1) * 20 +
    Math.max(0, progress.bestCharacterLevel - 1) * 20
  );
}

function readRequiredString(value, field, maxLength) {
  const text = readOptionalString(value, maxLength);
  if (!text) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return text;
}

function readOptionalString(value, maxLength) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  return trimmed.slice(0, maxLength);
}

function readStringArray(value, maxLength) {
  if (!Array.isArray(value)) {
    return [];
  }
  return [...new Set(value.filter((item) => typeof item === "string"))]
    .map((item) => item.slice(0, 128))
    .slice(0, maxLength);
}

function clampInt(value, min, max) {
  const parsed = readInt(value, min);
  return Math.min(Math.max(parsed, min), max);
}

function readInt(value, fallback) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return fallback;
  }
  return Math.trunc(value);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
