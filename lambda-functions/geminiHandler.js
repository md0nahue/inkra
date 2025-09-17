// V1 Polymorphic Lambda Handler - Single endpoint for all Gemini operations

const { GoogleGenerativeAI } = require('@google/generative-ai');
const { PROMPT_REGISTRY } = require('./prompts');
const { getPrompt, buildFullPrompt, validateInput } = require('./utils');

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

exports.handler = async (event) => {
    console.log('Request:', JSON.stringify(event, null, 2));

    try {
        // Parse request
        const body = JSON.parse(event.body || '{}');
        const { action, input, parameters = {} } = body;

        // Validate input
        const validation = validateInput(action, input);
        if (!validation.valid) {
            return createResponse(400, {
                error: 'Invalid request',
                message: validation.message
            });
        }

        // Get prompt template
        const promptTemplate = getPrompt(action);
        if (!promptTemplate) {
            return createResponse(400, {
                error: 'Invalid action',
                message: `Unknown action: ${action}. Available actions: ${Object.keys(PROMPT_REGISTRY).join(', ')}`
            });
        }

        // Build full prompt with parameters
        const fullPrompt = buildFullPrompt(promptTemplate, input, parameters);

        // Call Gemini
        const geminiResponse = await callGemini(fullPrompt, parameters, action);

        return createResponse(200, {
            success: true,
            action,
            result: geminiResponse,
            metadata: {
                generatedAt: new Date().toISOString(),
                action,
                parameters
            }
        });

    } catch (error) {
        console.error('Lambda error:', error);

        return createResponse(500, {
            error: 'Internal server error',
            message: error.message || 'An unexpected error occurred'
        });
    }
};

async function callGemini(prompt, parameters = {}, action = null) {
    try {
        const model = genAI.getGenerativeModel({
            model: parameters.model || 'gemini-1.5-flash'
        });

        const generationConfig = {
            temperature: parameters.temperature || 0.7,
            topP: parameters.topP || 0.8,
            topK: parameters.topK || 40,
            maxOutputTokens: parameters.maxTokens || 2000,
        };

        const result = await model.generateContent({
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            generationConfig,
        });

        const response = await result.response;
        const text = response.text();

        // Format response based on action type
        const { formatResponse } = require('./utils');
        return formatResponse(text, action);

    } catch (error) {
        console.error('Gemini API error:', error);

        // Return fallback response if available
        const { getFallbackResponse } = require('./utils');
        const fallback = getFallbackResponse(action, parameters);
        if (fallback) {
            console.log('Using fallback response for', action);
            return fallback;
        }

        throw new Error(`Gemini API failed: ${error.message}`);
    }
}

function createResponse(statusCode, body) {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'POST, OPTIONS'
        },
        body: JSON.stringify(body)
    };
}