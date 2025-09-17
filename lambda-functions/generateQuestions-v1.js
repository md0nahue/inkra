// V1 SIMPLIFIED - No authentication, no rate limiting, just Gemini API calls

const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

exports.handler = async (event) => {
    console.log('Request:', JSON.stringify(event, null, 2));

    try {
        // Parse request body
        const body = JSON.parse(event.body || '{}');
        const {
            position,
            company,
            yearsOfExperience = 'entry-level',
            difficulty = 'medium',
            questionType = 'mixed'
        } = body;

        // Basic validation
        if (!position || !company) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS'
                },
                body: JSON.stringify({
                    error: 'Missing required fields',
                    message: 'Position and company are required'
                })
            };
        }

        // Generate questions with Gemini
        const questions = await generateQuestions({
            position,
            company,
            yearsOfExperience,
            difficulty,
            questionType
        });

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            body: JSON.stringify({
                success: true,
                questions,
                metadata: {
                    position,
                    company,
                    yearsOfExperience,
                    difficulty,
                    questionType,
                    generatedAt: new Date().toISOString()
                }
            })
        };

    } catch (error) {
        console.error('Error generating questions:', error);

        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: 'Failed to generate questions',
                message: error.message || 'An unexpected error occurred'
            })
        };
    }
};

async function generateQuestions({ position, company, yearsOfExperience, difficulty, questionType }) {
    try {
        // Build the prompt
        const prompt = buildPrompt({ position, company, yearsOfExperience, difficulty, questionType });

        // Get the model
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

        // Generate content
        const result = await model.generateContent({
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            generationConfig: {
                temperature: 0.7,
                topP: 0.8,
                topK: 40,
                maxOutputTokens: 1500,
            }
        });

        const response = await result.response;
        const text = response.text();

        // Try to parse as JSON, fallback to text parsing if needed
        try {
            const cleanedText = text.replace(/```json\n?|\n?```/g, '').trim();
            const questions = JSON.parse(cleanedText);

            // Ensure array format
            if (Array.isArray(questions)) {
                return questions.map((q, idx) => ({
                    id: idx + 1,
                    question: q.question || q,
                    type: q.type || questionType,
                    category: q.category || 'General',
                    difficulty: q.difficulty || difficulty
                }));
            }
            return questions;
        } catch (parseError) {
            // Fallback: Return as simple text questions
            console.warn('Could not parse Gemini response as JSON, using text format');
            return [{
                id: 1,
                question: text,
                type: questionType,
                category: 'General',
                difficulty: difficulty
            }];
        }

    } catch (error) {
        console.error('Gemini API error:', error);

        // Return fallback questions if Gemini fails
        return getFallbackQuestions({ position, company });
    }
}

function buildPrompt({ position, company, yearsOfExperience, difficulty, questionType }) {
    const basePrompt = `Generate 5 interview questions for a ${position} role at ${company}.
    Candidate experience level: ${yearsOfExperience}
    Difficulty: ${difficulty}
    Question type: ${questionType}

    Return as a JSON array with this structure:
    [
      {
        "question": "The interview question",
        "type": "behavioral/technical/mixed",
        "category": "Category of the question",
        "difficulty": "easy/medium/hard"
      }
    ]`;

    const typeSpecificPrompts = {
        technical: `
            Focus on:
            - Programming concepts and best practices
            - System design and architecture
            - Problem-solving scenarios
            - Technology stack relevant to ${company}
            - Debugging and optimization`,

        behavioral: `
            Focus on:
            - Leadership and teamwork experiences
            - Conflict resolution
            - Communication skills
            - Time management
            - Company culture fit for ${company}`,

        mixed: `
            Include both technical and behavioral questions.
            Balance between coding/technical skills and soft skills.`
    };

    return basePrompt + (typeSpecificPrompts[questionType] || typeSpecificPrompts.mixed);
}

function getFallbackQuestions({ position, company }) {
    return [
        {
            id: 1,
            question: `Why are you interested in the ${position} role at ${company}?`,
            type: 'behavioral',
            category: 'Motivation',
            difficulty: 'easy'
        },
        {
            id: 2,
            question: `Describe a challenging technical problem you've solved recently.`,
            type: 'technical',
            category: 'Problem Solving',
            difficulty: 'medium'
        },
        {
            id: 3,
            question: `How do you stay updated with the latest technologies and trends?`,
            type: 'behavioral',
            category: 'Learning',
            difficulty: 'easy'
        },
        {
            id: 4,
            question: `Walk me through your approach to debugging a complex issue.`,
            type: 'technical',
            category: 'Debugging',
            difficulty: 'medium'
        },
        {
            id: 5,
            question: `Tell me about a time you had to work with a difficult team member.`,
            type: 'behavioral',
            category: 'Teamwork',
            difficulty: 'medium'
        }
    ];
}