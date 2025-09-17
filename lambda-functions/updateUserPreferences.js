const AWS = require('aws-sdk');

// Initialize AWS services
const cognito = new AWS.CognitoIdentityServiceProvider();

// Environment variables
const USER_POOL_ID = process.env.USER_POOL_ID;

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));

    try {
        // Parse the request
        const { body, requestContext } = event;
        const preferences = JSON.parse(body || '{}');

        // Extract user information from JWT token
        const claims = requestContext.authorizer.claims;
        const userId = claims.sub;

        // Validate and sanitize preferences
        const validatedPreferences = validatePreferences(preferences);

        // Update user attributes in Cognito
        await updateCognitoUserAttributes(userId, validatedPreferences);

        // Return updated preferences
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                message: 'Preferences updated successfully',
                updatedPreferences: validatedPreferences,
                updatedAt: new Date().toISOString()
            })
        };

    } catch (error) {
        console.error('Error:', error);

        // Handle specific Cognito errors
        if (error.code === 'UserNotConfirmedException') {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'User not confirmed',
                    message: 'Please confirm your email address before updating preferences'
                })
            };
        }

        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message
            })
        };
    }
};

function validatePreferences(preferences) {
    const validatedPrefs = {};

    // Voice preference validation
    if (preferences.voicePreference) {
        const validVoices = [
            'default',
            'nova',
            'alloy',
            'echo',
            'fable',
            'onyx',
            'shimmer'
        ];

        if (validVoices.includes(preferences.voicePreference)) {
            validatedPrefs.voicePreference = preferences.voicePreference;
        } else {
            throw new Error(`Invalid voice preference. Must be one of: ${validVoices.join(', ')}`);
        }
    }

    // Subscription tier validation (only allow if it's an upgrade)
    if (preferences.subscriptionTier) {
        const validTiers = ['free_tier', 'premium_tier'];

        if (validTiers.includes(preferences.subscriptionTier)) {
            validatedPrefs.subscriptionTier = preferences.subscriptionTier;
        } else {
            throw new Error(`Invalid subscription tier. Must be one of: ${validTiers.join(', ')}`);
        }
    }

    // Monthly quota validation (only if subscription tier is being updated)
    if (preferences.monthlyQuota && preferences.subscriptionTier) {
        const quota = parseInt(preferences.monthlyQuota);

        if (preferences.subscriptionTier === 'free_tier' && quota <= 300) {
            validatedPrefs.monthlyQuota = quota;
        } else if (preferences.subscriptionTier === 'premium_tier' && quota <= 3000) {
            validatedPrefs.monthlyQuota = quota;
        } else {
            throw new Error('Invalid monthly quota for the specified subscription tier');
        }
    }

    // Preferred username validation
    if (preferences.preferredUsername) {
        const username = preferences.preferredUsername.trim();
        if (username.length >= 3 && username.length <= 50 && /^[a-zA-Z0-9._-]+$/.test(username)) {
            validatedPrefs.preferredUsername = username;
        } else {
            throw new Error('Invalid username. Must be 3-50 characters and contain only letters, numbers, dots, hyphens, and underscores');
        }
    }

    // Interview preferences
    if (preferences.defaultDifficulty) {
        const validDifficulties = ['easy', 'medium', 'hard'];
        if (validDifficulties.includes(preferences.defaultDifficulty)) {
            validatedPrefs.defaultDifficulty = preferences.defaultDifficulty;
        }
    }

    if (preferences.defaultQuestionType) {
        const validTypes = ['behavioral', 'technical', 'mixed'];
        if (validTypes.includes(preferences.defaultQuestionType)) {
            validatedPrefs.defaultQuestionType = preferences.defaultQuestionType;
        }
    }

    // Notification preferences
    if (typeof preferences.emailNotifications === 'boolean') {
        validatedPrefs.emailNotifications = preferences.emailNotifications.toString();
    }

    if (typeof preferences.pushNotifications === 'boolean') {
        validatedPrefs.pushNotifications = preferences.pushNotifications.toString();
    }

    return validatedPrefs;
}

async function updateCognitoUserAttributes(userId, preferences) {
    try {
        // Prepare user attributes for Cognito
        const userAttributes = [];

        Object.keys(preferences).forEach(key => {
            let attributeName = key;

            // Map preference names to Cognito attribute names
            if (key === 'preferredUsername') {
                attributeName = 'preferred_username';
            } else if (!['preferred_username'].includes(key)) {
                // Add custom: prefix for custom attributes
                attributeName = `custom:${key}`;
            }

            userAttributes.push({
                Name: attributeName,
                Value: preferences[key].toString()
            });
        });

        if (userAttributes.length === 0) {
            throw new Error('No valid preferences provided');
        }

        // Update user attributes in Cognito
        const params = {
            UserPoolId: USER_POOL_ID,
            Username: userId,
            UserAttributes: userAttributes
        };

        await cognito.adminUpdateUserAttributes(params).promise();
        console.log(`User preferences updated for user ${userId}:`, preferences);

    } catch (error) {
        console.error('Error updating Cognito user attributes:', error);
        throw error;
    }
}