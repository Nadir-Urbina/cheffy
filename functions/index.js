/**
 * Cloud Functions for My Chefsito
 * Handles server-side operations including account deletion
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

// ============================================================================
// ACCOUNT DELETION
// ============================================================================

/**
 * Process Account Deletion Request
 * Triggered when a new document is created in account_deletions collection
 * Handles complete user data deletion across all collections
 */
exports.processAccountDeletion = onDocumentCreated(
    "account_deletions/{requestId}",
    async (event) => {
      const requestData = event.data.data();
      const userId = requestData.userId;

      logger.info(`🗑️ Processing account deletion for user: ${userId}`);

      try {
        // Update status to processing
        await event.data.ref.update({
          status: "processing",
          processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Execute deletion
        await deleteUserDataCompletely(userId);

        // Update status to completed
        await event.data.ref.update({
          status: "completed",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info(`✅ Account deletion completed for user: ${userId}`);
      } catch (error) {
        logger.error(`❌ Account deletion failed for user ${userId}:`, error);

        // Update status to failed
        await event.data.ref.update({
          status: "failed",
          error: error.message || "Unknown error",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    },
);

/**
 * Delete all user data completely
 * @param {string} userId - The ID of the user to delete
 */
async function deleteUserDataCompletely(userId) {
  const db = admin.firestore();
  const storage = admin.storage();

  logger.info(`🔄 Starting complete data deletion for user: ${userId}`);

  // 1. Delete scheduled meals
  logger.info("Deleting scheduled meals...");
  await deleteUserScheduledMeals(db, userId);

  // 2. Delete cooked recipes history
  logger.info("Deleting cooked recipes...");
  await deleteUserCookedRecipes(db, userId);

  // 3. Delete user preferences
  logger.info("Deleting user preferences...");
  await deleteUserPreferences(db, userId);

  // 4. Delete profile photo from Storage
  logger.info("Deleting profile photo...");
  await deleteUserProfilePhoto(storage, userId);

  // 5. Delete user document
  logger.info("Deleting user document...");
  await db.collection("users").doc(userId).delete();

  // 6. Delete Firebase Auth account
  logger.info("Deleting Firebase Auth account...");
  await admin.auth().deleteUser(userId);

  logger.info(`✅ All data deleted for user: ${userId}`);
}

/**
 * Delete all scheduled meals for a user
 * @param {admin.firestore.Firestore} db - Firestore database instance
 * @param {string} userId - The ID of the user
 */
async function deleteUserScheduledMeals(db, userId) {
  try {
    const mealsSnapshot = await db.collection("scheduled_meals")
        .where("userId", "==", userId)
        .get();

    if (mealsSnapshot.empty) {
      logger.info("No scheduled meals found");
      return;
    }

    logger.info(`Found ${mealsSnapshot.size} scheduled meals to delete`);

    // Delete in batches of 500 (Firestore limit)
    const batchSize = 500;
    const meals = mealsSnapshot.docs;

    for (let i = 0; i < meals.length; i += batchSize) {
      const batch = db.batch();
      const batchMeals = meals.slice(i, i + batchSize);

      batchMeals.forEach((meal) => {
        batch.delete(meal.ref);
      });

      await batch.commit();
      logger.info(`Deleted batch of ${batchMeals.length} scheduled meals`);
    }
  } catch (error) {
    logger.warn(`Error deleting scheduled meals: ${error.message}`);
  }
}

/**
 * Delete all cooked recipes for a user
 * @param {admin.firestore.Firestore} db - Firestore database instance
 * @param {string} userId - The ID of the user
 */
async function deleteUserCookedRecipes(db, userId) {
  try {
    const recipesSnapshot = await db.collection("cooked_recipes")
        .where("userId", "==", userId)
        .get();

    if (recipesSnapshot.empty) {
      logger.info("No cooked recipes found");
      return;
    }

    logger.info(`Found ${recipesSnapshot.size} cooked recipes to delete`);

    const batchSize = 500;
    const recipes = recipesSnapshot.docs;

    for (let i = 0; i < recipes.length; i += batchSize) {
      const batch = db.batch();
      const batchRecipes = recipes.slice(i, i + batchSize);

      batchRecipes.forEach((recipe) => {
        batch.delete(recipe.ref);
      });

      await batch.commit();
      logger.info(`Deleted batch of ${batchRecipes.length} cooked recipes`);
    }
  } catch (error) {
    logger.warn(`Error deleting cooked recipes: ${error.message}`);
  }
}

/**
 * Delete user preferences document
 * @param {admin.firestore.Firestore} db - Firestore database instance
 * @param {string} userId - The ID of the user
 */
async function deleteUserPreferences(db, userId) {
  try {
    await db.collection("user_preferences").doc(userId).delete();
    logger.info("User preferences deleted");
  } catch (error) {
    logger.warn(`Error deleting user preferences: ${error.message}`);
  }
}

/**
 * Delete user's profile photo from Firebase Storage
 * @param {admin.storage.Storage} storage - Firebase Storage instance
 * @param {string} userId - The ID of the user
 */
async function deleteUserProfilePhoto(storage, userId) {
  try {
    const bucket = storage.bucket();
    const file = bucket.file(`profile_photos/${userId}.jpg`);

    const [exists] = await file.exists();
    if (exists) {
      await file.delete();
      logger.info("Profile photo deleted");
    } else {
      logger.info("No profile photo found");
    }
  } catch (error) {
    logger.warn(`Error deleting profile photo: ${error.message}`);
  }
}
