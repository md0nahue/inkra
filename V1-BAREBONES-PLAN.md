# V1 - Barebones MVP Plan

## Goal
Create the absolute minimum viable product that demonstrates core interview functionality WITHOUT any authentication, user management, or complex infrastructure.

## Core Features ONLY

### 1. iOS Native TTS/STT ✅
**Already Implemented:**
- NativeSpeechService.swift - Speech recognition
- NativeVoiceService.swift - Text-to-speech
- AudioRecorder.swift - Recording functionality

**Action:** Keep as-is, these work great

### 2. Local Data Storage ✅
**Already Implemented:**
- Core Data models
- LocalAudioManager.swift
- Local segment storage

**Action:** Keep as-is, remove sync capabilities

### 3. Simple Lambda → Gemini Endpoint 🔧
**Current:** Over-engineered with auth, rate limiting, usage tracking
**Target:** Single Lambda that just calls Gemini API

**New Lambda (simplified):**
```javascript
// generateQuestions.js - V1 SIMPLE VERSION
const { GoogleGenerativeAI } = require('@google/generative-ai');
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

exports.handler = async (event) => {
    const { position, company } = JSON.parse(event.body);

    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    const prompt = `Generate 5 interview questions for ${position} at ${company}`;

    const result = await model.generateContent(prompt);
    return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ questions: result.response.text() })
    };
};
```

## Implementation Steps

### Phase 1: Strip Authentication (Day 1)
- [ ] Remove CognitoAuthService.swift
- [ ] Remove AuthService.swift
- [ ] Remove all JWT/token references
- [ ] Remove subscription tier logic
- [ ] Update InterviewManager to work without auth
- [ ] Update LambdaService for anonymous calls

### Phase 2: Simplify Infrastructure (Day 1-2)
- [ ] Create new `terraform/v1/` directory
- [ ] Single Lambda function (no auth)
- [ ] Simple API Gateway (no authorizer)
- [ ] Remove Cognito resources
- [ ] Remove DynamoDB usage table
- [ ] Minimal CloudWatch logging

### Phase 3: Update iOS App (Day 2)
- [ ] Remove login/signup screens
- [ ] Direct to interview flow
- [ ] Remove user-specific features
- [ ] Test TTS/STT flow
- [ ] Test Lambda integration

### Phase 4: Testing (Day 3)
- [ ] Test complete interview flow
- [ ] Test audio recording
- [ ] Test question generation
- [ ] Test export functionality

## V1 Architecture

```
iOS App (No Auth)
    ├── Native TTS/STT
    ├── Core Data Storage
    └── API Calls → API Gateway → Lambda → Gemini
```

## What We're NOT Building in V1
- ❌ User accounts
- ❌ Authentication
- ❌ Rate limiting
- ❌ Usage tracking
- ❌ Subscription tiers
- ❌ Cloud sync
- ❌ User profiles
- ❌ Feature flags
- ❌ Complex monitoring

## Success Criteria
1. User opens app → immediately can start interview
2. Questions generated from Lambda/Gemini
3. Audio recorded locally
4. Transcript saved locally
5. Can export interview

## Estimated Timeline
- Day 1: Strip auth, simplify infrastructure
- Day 2: Update iOS app, test integration
- Day 3: Final testing and bug fixes

## Next File to Create
- V2-FUTURE-FEATURES.md (all the nice-to-haves)