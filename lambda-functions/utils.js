// Utility functions for prompt processing

const { PROMPT_REGISTRY } = require('./prompts');

/**
 * Get prompt configuration for a given action
 */
function getPrompt(action) {
    if (!action || !PROMPT_REGISTRY[action]) {
        return null;
    }
    return PROMPT_REGISTRY[action];
}

/**
 * Validate input based on action requirements
 */
function validateInput(action, input) {
    if (!action) {
        return { valid: false, message: 'Action is required' };
    }

    const promptConfig = PROMPT_REGISTRY[action];
    if (!promptConfig) {
        return { valid: false, message: `Unknown action: ${action}` };
    }

    if (!input || typeof input !== 'object') {
        return { valid: false, message: 'Input must be an object' };
    }

    // Check required fields
    const missing = promptConfig.required.filter(field => !input[field]);
    if (missing.length > 0) {
        return {
            valid: false,
            message: `Missing required fields: ${missing.join(', ')}`
        };
    }

    return { valid: true };
}

/**
 * Build full prompt by replacing template variables
 */
function buildFullPrompt(promptConfig, input, parameters = {}) {
    let prompt = promptConfig.template;

    // Merge defaults with provided input
    const values = {
        ...promptConfig.defaults,
        ...input,
        ...parameters
    };

    // Replace all {{variable}} placeholders
    prompt = prompt.replace(/\{\{(\w+)\}\}/g, (match, variable) => {
        return values[variable] || match;
    });

    return prompt;
}

/**
 * List all available actions
 */
function listAvailableActions() {
    return Object.keys(PROMPT_REGISTRY).map(action => ({
        action,
        required: PROMPT_REGISTRY[action].required,
        description: getActionDescription(action)
    }));
}

/**
 * Get human-readable description for an action
 */
function getActionDescription(action) {
    const descriptions = {
        generate_questions: 'Generate interview questions for a position',
        generate_followup: 'Generate follow-up questions based on an answer',
        evaluate_answer: 'Evaluate and score an interview answer',
        generate_topics: 'Generate relevant interview topics',
        daily_question: 'Get a daily practice question',
        improve_answer: 'Improve an interview answer',
        generate_interview_script: 'Create a complete mock interview script',
        industry_insights: 'Get current interview trends for an industry',
        extract_talking_points: 'Extract key talking points from resume',
        company_research: 'Generate company-specific interview prep'
    };
    return descriptions[action] || 'No description available';
}

/**
 * Format Gemini response based on expected output type
 */
function formatResponse(text, action) {
    // Try to parse JSON responses
    if (text.includes('{') || text.includes('[')) {
        try {
            // Remove markdown code blocks if present
            const cleanedText = text
                .replace(/```json\n?/g, '')
                .replace(/```\n?/g, '')
                .trim();

            return JSON.parse(cleanedText);
        } catch (e) {
            // If JSON parsing fails, try to extract JSON from text
            const jsonMatch = text.match(/(\{[\s\S]*\}|\[[\s\S]*\])/);
            if (jsonMatch) {
                try {
                    return JSON.parse(jsonMatch[1]);
                } catch {
                    // Return as is if all parsing fails
                    return text;
                }
            }
        }
    }

    return text;
}

/**
 * Get a fallback response if Gemini fails
 */
function getFallbackResponse(action, input) {
    const fallbacks = {
        generate_questions: [
            {
                id: 1,
                question: `Tell me about your experience relevant to the ${input.position || 'position'} role.`,
                type: 'behavioral',
                category: 'Experience',
                difficulty: 'medium',
                tips: 'Focus on specific examples and quantifiable results.'
            },
            {
                id: 2,
                question: `Why are you interested in working at ${input.company || 'our company'}?`,
                type: 'behavioral',
                category: 'Motivation',
                difficulty: 'easy',
                tips: 'Research the company and align your values with theirs.'
            }
        ],
        daily_question: {
            question: "Describe a time when you had to learn something new quickly.",
            category: "Adaptability",
            tips: "Use the STAR method and emphasize your learning process.",
            example_themes: ["learning", "adaptability", "growth mindset"]
        },
        generate_followup: [
            "Can you elaborate on that point?",
            "What was the outcome?",
            "How would you handle that differently now?"
        ]
    };

    return fallbacks[action] || {
        error: 'Service temporarily unavailable',
        message: 'Please try again later'
    };
}

module.exports = {
    getPrompt,
    validateInput,
    buildFullPrompt,
    listAvailableActions,
    getActionDescription,
    formatResponse,
    getFallbackResponse
};