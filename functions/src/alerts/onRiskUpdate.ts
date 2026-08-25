import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

/**
 * Watches districts_risk/{districtId}, written by the ML pipeline / backend
 * risk service. When a district's risk_level crosses into "high" or
 * "very_high", automatically fan out push (FCM topic per district) and SMS
 * alerts. Analyst/admin manual overrides go through the
 * POST /api/v1/alerts/trigger backend endpoint instead, which should write
 * to the same alerts/ collection for a single source of truth.
 *
 * TODO:
 *  - debounce so repeated writes at the same level don't re-alert
 *  - send FCM to topic `district_<districtId>`
 *  - call sendSmsAlert (or the gateway directly) for subscribed numbers
 */
export const onRiskUpdateTriggerAlert = onDocumentWritten(
  "districts_risk/{districtId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;

    const escalated =
      (!before || before.risk_level !== after.risk_level) &&
      (after.risk_level === "high" || after.risk_level === "very_high");

    if (!escalated) return;

    await admin.firestore().collection("alerts").add({
      district: event.params.districtId,
      risk_level: after.risk_level,
      message: `Landslide risk in ${event.params.districtId} escalated to ${after.risk_level}.`,
      source: "auto",
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // TODO: trigger push (FCM) + SMS fan-out here or via a follow-up
    // onDocumentCreated("alerts/{alertId}") trigger.
  }
);
