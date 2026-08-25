import { onDocumentCreated } from "firebase-functions/v2/firestore";

/**
 * Notifies analyst/admin users (via FCM topic "role_analyst_admin") whenever
 * a new citizen or field_official report is submitted, so the moderation
 * queue in the analyst home screen has a live badge/notification.
 *
 * TODO: send FCM to topic "role_analyst_admin"; consider a higher-priority
 * notification when reporter_role === "field_official" given their reports
 * are trust-weighted higher.
 */
export const onReportCreateNotifyAnalysts = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const report = event.data?.data();
    if (!report) return;

    console.log("New report submitted, TODO notify analysts:", event.params.reportId);
  }
);
