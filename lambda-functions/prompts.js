// Prompt Registry - All Gemini prompts centralized here

const PROMPT_REGISTRY = {
    // Interview question generation
    generate_questions: {
        template: `You are an expert interview coach. Generate {{num_questions}} interview questions for a {{position}} position at {{company}}.

        Experience level: {{experience_level}}
        Question type: {{question_type}}
        Difficulty: {{difficulty}}

        Return as a JSON array with this structure:
        [
          {
            "id": 1,
            "question": "The interview question",
            "type": "behavioral/technical",
            "category": "Category",
            "difficulty": "easy/medium/hard",
            "tips": "Answer tips"
          }
        ]`,
        defaults: {
            num_questions: 5,
            experience_level: 'mid-level',
            question_type: 'mixed',
            difficulty: 'medium'
        },
        required: ['position', 'company']
    },

    // Follow-up question generation
    generate_followup: {
        template: `You are an expert interview coach. Based on this Q&A exchange, generate {{num_followups}} natural follow-up questions.

        Original Question: {{original_question}}
        User's Answer: {{user_answer}}

        Generate follow-up questions that:
        - Dig deeper into specific points mentioned
        - Clarify any ambiguities
        - Test understanding further
        - Are natural and conversational

        Return as a JSON array of strings.`,
        defaults: {
            num_followups: 3
        },
        required: ['original_question', 'user_answer']
    },

    // Answer evaluation
    evaluate_answer: {
        template: `You are an expert interview coach. Evaluate this interview answer.

        Question: {{question}}
        Answer: {{answer}}
        Position: {{position}}

        Provide feedback on:
        1. Strengths of the answer
        2. Areas for improvement
        3. Suggested improvements
        4. STAR method usage (if applicable)
        5. Overall score (1-10)

        Return as JSON with structure:
        {
          "score": 7,
          "strengths": ["..."],
          "improvements": ["..."],
          "suggestions": ["..."],
          "star_analysis": {...}
        }`,
        defaults: {
            position: 'Software Engineer'
        },
        required: ['question', 'answer']
    },

    // Generate interview topics
    generate_topics: {
        template: `Generate {{num_topics}} relevant interview topics for a {{position}} role at {{company}}.

        Focus on topics that would be relevant for someone with {{experience_level}} experience.

        Return as a JSON array of objects:
        [
          {
            "topic": "Topic name",
            "description": "Brief description",
            "sample_question": "One example question"
          }
        ]`,
        defaults: {
            num_topics: 10,
            experience_level: 'mid-level'
        },
        required: ['position', 'company']
    },

    // Generate daily practice question
    daily_question: {
        template: `Generate a single daily practice interview question.

        Make it:
        - Thought-provoking
        - Applicable to most professionals
        - Focus on: {{focus_area}}

        Return as JSON:
        {
          "question": "The question",
          "category": "Category",
          "tips": "How to approach this question",
          "example_themes": ["theme1", "theme2"]
        }`,
        defaults: {
            focus_area: 'personal growth and reflection'
        },
        required: []
    },

    // Improve answer
    improve_answer: {
        template: `You are an expert interview coach. Improve this interview answer while maintaining the speaker's authentic voice.

        Question: {{question}}
        Original Answer: {{original_answer}}

        Improve the answer by:
        - Adding specific examples if missing
        - Structuring with STAR method if applicable
        - Removing filler words
        - Making it more concise
        - Adding quantifiable results where possible

        Return as JSON:
        {
          "improved_answer": "The improved version",
          "key_changes": ["change1", "change2"],
          "structure_type": "STAR/CAR/General"
        }`,
        defaults: {},
        required: ['question', 'original_answer']
    },

    // Mock interview script
    generate_interview_script: {
        template: `Create a complete mock interview script for a {{position}} at {{company}}.

        Duration: {{duration}} minutes
        Difficulty: {{difficulty}}

        Include:
        - Opening/rapport building (2 min)
        - {{num_questions}} main questions with timing
        - Expected follow-ups
        - Closing questions

        Return as JSON with full interview structure and timing.`,
        defaults: {
            duration: 30,
            difficulty: 'medium',
            num_questions: 6
        },
        required: ['position', 'company']
    },

    // Industry insights
    industry_insights: {
        template: `Provide current interview trends and insights for {{industry}} in {{year}}.

        Include:
        - Most common question themes
        - What companies are looking for
        - Red flags to avoid
        - Unique trends in this industry

        Return as structured JSON with actionable insights.`,
        defaults: {
            year: new Date().getFullYear()
        },
        required: ['industry']
    },

    // Resume talking points
    extract_talking_points: {
        template: `Based on this resume excerpt, identify key talking points for interviews.

        Resume: {{resume_text}}
        Target Role: {{target_role}}

        Extract:
        - Key achievements with metrics
        - Relevant skills to emphasize
        - Potential stories for behavioral questions
        - Gaps or concerns to address

        Return as structured JSON.`,
        defaults: {
            target_role: 'Software Engineer'
        },
        required: ['resume_text']
    },

    // Company research
    company_research: {
        template: `Generate interview preparation notes for {{company}}.

        Include:
        - Company mission/values to reference
        - Recent news to mention
        - Common interview themes at this company
        - Questions to ask interviewers
        - Cultural fit talking points

        Be specific and actionable. Return as structured JSON.`,
        defaults: {},
        required: ['company']
    }
};

module.exports = { PROMPT_REGISTRY };