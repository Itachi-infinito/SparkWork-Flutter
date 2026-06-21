import * as admin from 'firebase-admin';
admin.initializeApp();

export { createVeriffSession } from './veriff/createSession';
export { veriffWebhook } from './veriff/webhook';
export { onHireConfirmed } from './match/onHireConfirmed';
export { ratingReminder } from './scheduled/ratingReminder';
export { onReferralCreated } from './partner/onReferralCreated';
export { onRatingCreated } from './rating/onRatingCreated';
export { receiveRevenueCatWebhook } from './revenuecat/webhook';
export { createActiveSession } from './security/createActiveSession';
export { resolveSecurityFlag } from './security/resolveSecurityFlag';
export {
  requestRestrictedUnlockOtp,
  verifyRestrictedUnlockOtp,
  adminUnlockRestrictedAccount,
} from './security/restrictedModeUnlock';
export { aggregateSecurityDashboard } from './security/securityDashboard';
export { cleanupSecurityLogs } from './security/cleanupSecurityLogs';
export { deleteMySecurityLogs } from './security/deleteMySecurityLogs';
export { calculateSparkScore } from './sparkscore/calculateSparkScore';
export { onSwipeVoteWritten } from './competition/onSwipeVoteWritten';
export { calculateCandidateAnalytics } from './analytics/calculateCandidateAnalytics';
export { activateSmartBoost } from './sparkboost/activateSmartBoost';
export { generateMatchReport } from './matchreport/generateMatchReport';
export { regenerateMatchReport } from './matchreport/regenerateMatchReport';
export { onSparkInviteCreated } from './sparkinvite/onSparkInviteCreated';
export { createStripeIdentitySession } from './stripeidentity/createStripeIdentitySession';
export { stripeIdentityWebhook } from './stripeidentity/stripeIdentityWebhook';
export { createDailyRoom } from './dailyco/createDailyRoom';
export { videoInterviewReminder } from './dailyco/videoInterviewReminder';
