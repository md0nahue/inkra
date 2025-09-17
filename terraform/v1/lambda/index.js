const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

exports.handler = async (event) => {
    console.log('Received event:', JSON.stringify(event, null, 2));

    try {
        // Parse request body
        const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
        const { position, company } = body;

        if (!position) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Missing required field: position'
                })
            };
        }

        // Generate questions using Gemini
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

        const companyText = company ? ` at ${company}` : '';
        const prompt = `Generate 5 interview questions for a ${position} position${companyText}.
        Return the questions as a JSON array with the following format:
        [
            {
                "id": 1,
                "question": "question text here",
                "type": "behavioral",
                "category": "General",
                "difficulty": "medium"
            }
        ]

        Focus on behavioral and situational questions that are commonly asked for this role.`;

        console.log('Generating questions with prompt:', prompt);

        const result = await model.generateContent(prompt);
        const response = await result.response;
        const text = response.text();

        console.log('Gemini response:', text);

        // Try to extract JSON from the response
        let questions;
        try {
            // Remove markdown code blocks if present
            const cleanText = text.replace(/```json\n?|\n?```/g, '').trim();
            questions = JSON.parse(cleanText);
        } catch (parseError) {
            console.error('Failed to parse Gemini response as JSON:', parseError);
            // Fallback to mock questions
            questions = [
                {
                    id: 1,
                    question: `Tell me about your experience with ${position} roles${companyText}.`,
                    type: "behavioral",
                    category: "General",
                    difficulty: "medium"
                },
                {
                    id: 2,
                    question: "Describe a challenging project you worked on and how you overcame obstacles.",
                    type: "behavioral",
                    category: "Problem Solving",
                    difficulty: "medium"
                },
                {
                    id: 3,
                    question: "How do you stay current with industry trends and technologies?",
                    type: "behavioral",
                    category: "Learning",
                    difficulty: "easy"
                },
                {
                    id: 4,
                    question: "Tell me about a time when you had to work with a difficult team member.",
                    type: "behavioral",
                    category: "Teamwork",
                    difficulty: "medium"
                },
                {
                    id: 5,
                    question: "Where do you see yourself in 5 years?",
                    type: "behavioral",
                    category: "Career Goals",
                    difficulty: "easy"
                }
            ];
        }

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
                    company: company || null,
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
                message: error.message
            })
        };
    }
};