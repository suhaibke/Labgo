const admin = require('firebase-admin');
const User = require('../models/User');
const Notification = require('../models/Notification');

// Service account is a secret and is never committed to git. In production it's
// supplied via the FIREBASE_SERVICE_ACCOUNT_JSON env var; for local dev it falls
// back to the gitignored JSON file in the backend root.
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)
  : require('../labgo-6dcc9-firebase-adminsdk-fbsvc-0e2601af5c.json');

// Initialize Firebase Admin (only once)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

/**
 * Send notification to a topic (for broadcasts)
 * @param {string} topic - Topic name (e.g., 'all_patients', 'nurse_city_baghdad')
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Additional data payload
 */
async function sendToTopic(topic, title, body, data = {}) {
  try {
    const message = {
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      topic: topic
    };
    const response = await admin.messaging().send(message);
    console.log('FCM topic notification sent:', response);
    return response;
  } catch (error) {
    console.error('FCM topic notification error:', error);
    throw error;
  }
}

/**
 * Send notification to a specific user
 * @param {string} userId - User's MongoDB _id
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Additional data payload
 */
async function sendToUser(userId, title, body, data = {}) {
  // Keep an in-app history row regardless of push delivery outcome (no
  // token registered, device offline, permission denied, ...) so the
  // notifications screen still has something to show.
  try {
    await Notification.create({ userId, title, body, data });
  } catch (dbError) {
    console.error('FCM: Failed to save notification history:', dbError);
  }

  try {
    const user = await User.findById(userId);
    if (!user || !user.fcmTokens || user.fcmTokens.length === 0) {
      console.log('FCM: No tokens found for user', userId);
      return null;
    }

    const tokens = user.fcmTokens.map(t => t.token);
    const message = {
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      tokens: tokens
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log('FCM user notification sent:', response.successCount, 'success,', response.failureCount, 'failed');

    // Remove invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          invalidTokens.push(tokens[idx]);
        }
      });
      if (invalidTokens.length > 0) {
        await User.findByIdAndUpdate(userId, {
          $pull: { fcmTokens: { token: { $in: invalidTokens } } }
        });
        console.log('FCM: Removed', invalidTokens.length, 'invalid tokens');
      }
    }

    return response;
  } catch (error) {
    console.error('FCM user notification error:', error);
    throw error;
  }
}

module.exports = {
  sendToTopic,
  sendToUser
};
