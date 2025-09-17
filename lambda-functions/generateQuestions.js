const AWS = require('aws-sdk');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize AWS services
const dynamodb = new AWS.DynamoDB.DocumentClient();
const cognito = new AWS.CognitoIdentityServiceProvider();

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Constants
const USAGE_TABLE = process.env.USAGE_TABLE;
const USER_POOL_ID = process.env.USER_POOL_ID;
const FREE_TIER_LIMIT = parseInt(process.env.FREE_TIER_DAILY_LIMIT) || 10;
const PREMIUM_TIER_LIMIT = parseInt(process.env.PREMIUM_TIER_DAILY_LIMIT) || 100;

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));

    try {
        // Parse the request
        const { body, requestContext } = event;
        const { position, company, yearsOfExperience, difficulty, questionType } = JSON.parse(body || '{}');

        // Extract user information from JWT token
        const claims = requestContext.authorizer.claims;
        const userId = claims.sub;

        // Get user's current subscription tier and check rate limits
        const rateLimitCheck = await checkRateLimit(userId);
        if (!rateLimitCheck.allowed) {
            return {
                statusCode: 429,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Rate limit exceeded',
                    message: rateLimitCheck.message,
                    dailyUsage: rateLimitCheck.dailyUsage,
                    dailyLimit: rateLimitCheck.dailyLimit,
                    resetTime: rateLimitCheck.resetTime
                })
            };
        }

        // Validate required parameters
        if (!position || !company) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Missing required parameters',
                    message: 'Position and company are required'
                })
            };
        }

        // Generate questions using Gemini
        const questions = await generateQuestionsWithGemini({
            position,
            company,
            yearsOfExperience: yearsOfExperience || 'entry-level',
            difficulty: difficulty || 'medium',
            questionType: questionType || 'behavioral'
        });

        // Record usage
        await recordUsage(userId, rateLimitCheck.subscriptionTier);

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                questions,
                metadata: {
                    position,
                    company,
                    yearsOfExperience,
                    difficulty,
                    questionType,
                    generatedAt: new Date().toISOString(),
                    dailyUsage: rateLimitCheck.dailyUsage + 1,
                    dailyLimit: rateLimitCheck.dailyLimit
                }
            })
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

async function checkRateLimit(userId) {
    try {
        // Get current date and hour for tracking
        const now = new Date();
        const date = now.toISOString().split('T')[0]; // YYYY-MM-DD

        // Get user's subscription tier from Cognito
        let subscriptionTier = 'free_tier';
        let dailyLimit = FREE_TIER_LIMIT;

        try {
            const userParams = {
                UserPoolId: USER_POOL_ID,
                Username: userId
            };

            const userData = await cognito.adminGetUser(userParams).promise();
            const customAttributes = userData.UserAttributes || [];

            const tierAttribute = customAttributes.find(attr => attr.Name === 'custom:subscription_tier');
            if (tierAttribute && tierAttribute.Value === 'premium_tier') {
                subscriptionTier = 'premium_tier';
                dailyLimit = PREMIUM_TIER_LIMIT;
            }
        } catch (cognitoError) {
            console.warn('Could not fetch user subscription tier:', cognitoError.message);
            // Default to free tier if we can't determine subscription
        }

        // Query daily usage from DynamoDB
        const queryParams = {
            TableName: USAGE_TABLE,
            KeyConditionExpression: 'user_id = :userId AND begins_with(date_hour, :date)',
            ExpressionAttributeValues: {
                ':userId': userId,
                ':date': date
            }
        };

        const result = await dynamodb.query(queryParams).promise();
        const dailyUsage = result.Items.reduce((total, item) => total + (item.request_count || 0), 0);

        // Check if user has exceeded their daily limit
        if (dailyUsage >= dailyLimit) {
            const resetTime = new Date(now);
            resetTime.setUTCDate(resetTime.getUTCDate() + 1);
            resetTime.setUTCHours(0, 0, 0, 0);

            return {
                allowed: false,
                message: `Daily limit of ${dailyLimit} questions exceeded. Limit resets at midnight UTC.`,
                dailyUsage,
                dailyLimit,
                subscriptionTier,
                resetTime: resetTime.toISOString()
            };
        }

        return {
            allowed: true,
            dailyUsage,
            dailyLimit,
            subscriptionTier
        };

    } catch (error) {
        console.error('Rate limit check error:', error);
        // In case of error, allow the request but log the issue
        return {
            allowed: true,
            dailyUsage: 0,
            dailyLimit: FREE_TIER_LIMIT,
            subscriptionTier: 'free_tier'
        };
    }
}

async function recordUsage(userId, subscriptionTier) {
    try {
        const now = new Date();
        const date = now.toISOString().split('T')[0];
        const dateHour = `${date}_${now.getUTCHours().toString().padStart(2, '0')}`;
        const ttl = Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60); // 90 days TTL

        const params = {
            TableName: USAGE_TABLE,
            Key: {
                user_id: userId,
                date_hour: dateHour
            },
            UpdateExpression: 'ADD request_count :inc SET #date = :date, subscription_tier = :tier, #ttl = :ttl, last_request = :timestamp',
            ExpressionAttributeNames: {
                '#date': 'date',
                '#ttl': 'ttl'
            },
            ExpressionAttributeValues: {
                ':inc': 1,
                ':date': date,
                ':tier': subscriptionTier,
                ':ttl': ttl,
                ':timestamp': now.toISOString()
            }
        };

        await dynamodb.update(params).promise();
        console.log(`Usage recorded for user ${userId}: ${dateHour}`);

    } catch (error) {
        console.error('Error recording usage:', error);
        // Don't throw error to avoid blocking the response
    }
}

async function generateQuestionsWithGemini(params) {
    try {
        const { position, company, yearsOfExperience, difficulty, questionType } = params;

        // Create the prompt based on question type
        let prompt = '';

        if (questionType === 'technical') {
            prompt = `Generate 5 technical interview questions for a ${position} position at ${company}.
            The candidate has ${yearsOfExperience} years of experience.
            Difficulty level: ${difficulty}.

            Focus on:
            - Core technical skills for this role
            - Problem-solving scenarios
            - System design concepts (if applicable)
            - Coding challenges or algorithms
            - Technology-specific questions

            Return the response as a JSON array of objects, each with 'question', 'category', and 'difficulty' fields.`;

        } else if (questionType === 'behavioral') {
            prompt = `Generate 5 behavioral interview questions for a ${position} position at ${company}.
            The candidate has ${yearsOfExperience} years of experience.
            Difficulty level: ${difficulty}.

            Focus on:
            - Leadership and teamwork
            - Problem-solving approach
            - Communication skills
            - Adaptability and learning
            - Conflict resolution
            - Company culture fit

            Return the response as a JSON array of objects, each with 'question', 'category', and 'followUpTips' fields.`;

        } else {
            prompt = `Generate 5 mixed interview questions (technical and behavioral) for a ${position} position at ${company}.
            The candidate has ${yearsOfExperience} years of experience.
            Difficulty level: ${difficulty}.

            Include both technical and behavioral questions that would be relevant for this role.

            Return the response as a JSON array of objects, each with 'question', 'type', 'category', and 'difficulty' fields.`;
        }

        // Get the generative model
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

        // Configure generation parameters
        const generationConfig = {
            temperature: 0.7,
            topP: 0.8,
            topK: 40,
            maxOutputTokens: 2048,
        };

        // Generate content
        const result = await model.generateContent({
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            generationConfig,
        });

        const response = await result.response;
        const text = response.text();

        // Parse JSON response
        try {
            // Clean up the response text (remove any markdown formatting)
            const cleanedText = text.replace(/```json\n?|\n?```/g, '').trim();
            const questions = JSON.parse(cleanedText);

            // Validate the response structure
            if (!Array.isArray(questions)) {
                throw new Error('Response is not an array');
            }

            // Ensure each question has required fields
            const validatedQuestions = questions.map((q, index) => ({
                id: index + 1,
                question: q.question || 'Question not provided',
                type: q.type || questionType,
                category: q.category || 'General',
                difficulty: q.difficulty || difficulty,
                followUpTips: q.followUpTips || q.tips || null
            }));

            return validatedQuestions;

        } catch (parseError) {
            console.error('Failed to parse Gemini response as JSON:', parseError.message);
            console.error('Raw response:', text);

            // Fallback: return a structured error response
            return [{
                id: 1,
                question: `Tell me about your experience with ${position} roles and why you're interested in working at ${company}.`,
                type: 'behavioral',
                category: 'General',
                difficulty: difficulty,
                followUpTips: 'Focus on specific examples and connect your experience to the company\'s mission.'
            }];
        }

    } catch (error) {
        console.error('Gemini API error:', error);

        // Fallback questions if Gemini fails
        const { position, company, yearsOfExperience, difficulty } = params;
        return [
            {
                id: 1,
                question: `What interests you most about the ${position} role at ${company}?`,
                type: 'behavioral',
                category: 'Motivation',
                difficulty: 'easy',
                followUpTips: 'Research the company\'s recent projects and mission.'
            },
            {
                id: 2,
                question: `Describe a challenging project you worked on in your ${yearsOfExperience} years of experience.`,
                type: 'behavioral',
                category: 'Problem Solving',
                difficulty: difficulty,
                followUpTips: 'Use the STAR method: Situation, Task, Action, Result.'
            }
        ];
    }
}