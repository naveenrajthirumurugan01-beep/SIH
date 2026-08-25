import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";

/**
 * Fires on every new alerts/{alertId} doc (auto-triggered from
 * onRiskUpdate.ts, or manually created via the backend's
 * POST /api/v1/alerts/trigger) and sends SMS to subscribed numbers in that
 * district. Required per PS 26001: NER connectivity is patchy, so SMS is
 * mandatory alongside push notifications, not a nice-to-have.
 *
 * TODO:
 *  - query users where district == alert.district for phone_number
 *  - call Twilio or MSG91 REST API (mirror backend/app/services/sms_service.py's
 *    provider choice, or centralize by calling the FastAPI backend instead
 *    of duplicating the gateway integration here)
 */
const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");

export const sendSmsAlert = onDocumentCreated(
  { document: "alerts/{alertId}", secrets: [twilioAuthToken] },
  async (event) => {
    const alert = event.data?.data();
    if (!alert) return;

    // TODO: implement SMS fan-out.
    console.warn("sendSmsAlert stub: no SMS sent for alert", event.params.alertId);
  }
);
