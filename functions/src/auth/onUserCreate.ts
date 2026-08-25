import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

/**
 * When a user profile doc is created at users/{uid} (written by the
 * FastAPI backend right after Firebase Auth signup), mirror the chosen
 * role onto the user's Auth custom claims so it's available in every
 * subsequent ID token (used by backend/app/core/security.py and by
 * Firestore security rules via request.auth.token.role).
 *
 * TODO: validate that `role` is one of citizen | field_official | analyst_admin
 * and reject/flag anything else (e.g. analyst_admin should probably require
 * manual approval rather than self-signup).
 */
export const onUserCreateSetRole = onDocumentCreated("users/{uid}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const { uid } = event.params;
  const role = snapshot.data().role;

  await admin.auth().setCustomUserClaims(uid, { role });
});
