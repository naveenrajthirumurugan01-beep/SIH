import * as admin from "firebase-admin";

admin.initializeApp();

export { onUserCreateSetRole } from "./auth/onUserCreate";
export { onRiskUpdateTriggerAlert } from "./alerts/onRiskUpdate";
export { sendSmsAlert } from "./alerts/sendSmsAlert";
export { onReportCreateNotifyAnalysts } from "./reports/onReportCreate";
