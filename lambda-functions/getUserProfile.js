const AWS = require('aws-sdk');

// Initialize AWS services
const dynamodb = new AWS.DynamoDB.DocumentClient();
const cognito = new AWS.CognitoIdentityServiceProvider();

// Environment variables
const USAGE_TABLE = process.env.USAGE_TABLE;
const USER_POOL_ID = process.env.USER_POOL_ID;

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));

    try {
        // Extract user information from JWT token
        const claims = event.requestContext.authorizer.claims;
        const userId = claims.sub;
        const email = claims.email;

        // Get user profile from Cognito
        const userProfile = await getUserFromCognito(userId);

        // Get usage statistics
        const usageStats = await getUserUsageStats(userId);

        // Construct response
        const profile = {
            userId,
            email,
            username: userProfile.username,
            emailVerified: userProfile.emailVerified,
            subscriptionTier: userProfile.subscriptionTier || 'free_tier',
            monthlyQuota: userProfile.monthlyQuota || 300,
            voicePreference: userProfile.voicePreference || 'default',
            createdAt: userProfile.createdAt,
            lastModified: userProfile.lastModified,
            usage: usageStats
        };

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify(profile)
        };

    } catch (error) {
        console.error('Error:', error);

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

async function getUserFromCognito(userId) {
    try {
        const params = {
            UserPoolId: USER_POOL_ID,
            Username: userId
        };

        const result = await cognito.adminGetUser(params).promise();

        // Parse user attributes
        const attributes = {};
        result.UserAttributes.forEach(attr => {
            const key = attr.Name.replace('custom:', '');
            attributes[key] = attr.Value;
        });

        return {
            userId: result.Username,
            email: attributes.email,
            username: attributes.preferred_username || attributes.email,
            emailVerified: attributes.email_verified === 'true',
            subscriptionTier: attributes.subscription_tier || 'free_tier',
            monthlyQuota: parseInt(attributes.monthly_quota) || 300,
            voicePreference: attributes.voice_preference || 'default',
            createdAt: result.UserCreateDate,
            lastModified: result.UserLastModifiedDate,
            status: result.UserStatus,
            enabled: result.Enabled
        };

    } catch (error) {
        console.error('Error fetching user from Cognito:', error);
        throw new Error('Failed to fetch user profile');
    }
}

async function getUserUsageStats(userId) {
    try {
        // Get current date for daily usage
        const today = new Date().toISOString().split('T')[0];

        // Get this month's date range
        const currentMonth = new Date();
        const monthStart = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1).toISOString().split('T')[0];
        const monthEnd = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0).toISOString().split('T')[0];

        // Query daily usage
        const dailyParams = {
            TableName: USAGE_TABLE,
            KeyConditionExpression: 'user_id = :userId AND begins_with(date_hour, :date)',
            ExpressionAttributeValues: {
                ':userId': userId,
                ':date': today
            }
        };

        const dailyResult = await dynamodb.query(dailyParams).promise();
        const dailyUsage = dailyResult.Items.reduce((total, item) => total + (item.request_count || 0), 0);

        // Query monthly usage using GSI
        const monthlyParams = {
            TableName: USAGE_TABLE,
            IndexName: 'DateIndex',
            KeyConditionExpression: '#date BETWEEN :start AND :end',
            FilterExpression: 'user_id = :userId',
            ExpressionAttributeNames: {
                '#date': 'date'
            },
            ExpressionAttributeValues: {
                ':start': monthStart,
                ':end': monthEnd,
                ':userId': userId
            }
        };

        const monthlyResult = await dynamodb.query(monthlyParams).promise();
        const monthlyUsage = monthlyResult.Items.reduce((total, item) => total + (item.request_count || 0), 0);

        // Get usage history for the last 30 days
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        const historyStartDate = thirtyDaysAgo.toISOString().split('T')[0];

        const historyParams = {
            TableName: USAGE_TABLE,
            IndexName: 'DateIndex',
            KeyConditionExpression: '#date BETWEEN :start AND :end',
            FilterExpression: 'user_id = :userId',
            ExpressionAttributeNames: {
                '#date': 'date'
            },
            ExpressionAttributeValues: {
                ':start': historyStartDate,
                ':end': today,
                ':userId': userId
            }
        };

        const historyResult = await dynamodb.query(historyParams).promise();

        // Group usage by date
        const dailyHistory = {};
        historyResult.Items.forEach(item => {
            if (!dailyHistory[item.date]) {
                dailyHistory[item.date] = 0;
            }
            dailyHistory[item.date] += item.request_count || 0;
        });

        // Convert to array format for easier consumption
        const historyArray = Object.keys(dailyHistory)
            .sort()
            .slice(-30) // Last 30 days
            .map(date => ({
                date,
                count: dailyHistory[date]
            }));

        return {
            daily: {
                date: today,
                count: dailyUsage
            },
            monthly: {
                month: `${currentMonth.getFullYear()}-${(currentMonth.getMonth() + 1).toString().padStart(2, '0')}`,
                count: monthlyUsage
            },
            history: historyArray,
            lastUpdated: new Date().toISOString()
        };

    } catch (error) {
        console.error('Error fetching usage stats:', error);
        return {
            daily: { date: new Date().toISOString().split('T')[0], count: 0 },
            monthly: { month: new Date().toISOString().slice(0, 7), count: 0 },
            history: [],
            lastUpdated: new Date().toISOString()
        };
    }
}