# Test Suite Documentation

## Overview

This test suite provides comprehensive coverage for the Interview Question Service and API endpoints using RSpec with VCR for HTTP interaction recording.

## Test Structure

### Service Tests (`spec/services/interview_question_service_spec.rb`)
- **InterviewQuestionService**: Tests for the core LLM service
  - `#generate_interview_outline`: Tests outline generation with various options
  - `#generate_section_questions`: Tests additional question generation for sections
  - `#refine_questions`: Tests question refinement based on feedback
  - Error handling for API failures and malformed responses
  - Private method testing for response parsing

### Controller Tests (`spec/controllers/api/interview_questions_controller_spec.rb`)
- **Api::InterviewQuestionsController**: Tests for all API endpoints
  - `POST /api/interview_questions/generate_outline`
  - `POST /api/interview_questions/generate_section_questions`
  - `POST /api/interview_questions/refine_questions`
  - `POST /api/interview_questions/create_project_from_outline`
  - `POST /api/interview_questions/add_questions_to_section`
  - Authentication bypass for testing
  - Error scenarios and edge cases

## VCR Configuration

### Cassettes Location
All HTTP interactions are recorded in `spec/vcr_cassettes/`

### Security Features
- API keys are automatically filtered and replaced with `<FILTERED_API_KEY>`
- URL parameters containing keys are sanitized
- URI matching excludes the `key` parameter for flexibility

### Cassette Files
- `interview_outline_generation.yml`: Basic outline generation
- `interview_outline_custom_options.yml`: Outline with custom parameters
- `section_questions_generation.yml`: Additional section questions
- `question_refinement.yml`: Question refinement with feedback

## Factory Bot Factories

### Models Covered
- `User`: Basic user with premium trait
- `Project`: Projects with optional outline structure
- `Chapter`: Chapters with optional sections
- `Section`: Sections with optional questions
- `Question`: Individual interview questions

## Running Tests

```bash
# Run all interview question tests
bundle exec rspec spec/services/interview_question_service_spec.rb spec/controllers/api/interview_questions_controller_spec.rb

# Run only VCR tests (with HTTP interactions)
bundle exec rspec --tag vcr

# Run service tests only
bundle exec rspec spec/services/interview_question_service_spec.rb

# Run controller tests only
bundle exec rspec spec/controllers/api/interview_questions_controller_spec.rb
```

## Test Coverage

### Service Tests (15 examples)
- ✅ Outline generation with valid input
- ✅ Custom options handling
- ✅ Section question generation
- ✅ Question refinement
- ✅ Error handling for missing API key
- ✅ HTTP request failure handling
- ✅ JSON parsing (valid, markdown-wrapped, malformed)
- ✅ Response enhancement and validation

### Controller Tests (22 examples)
- ✅ All 5 API endpoints with valid inputs
- ✅ Parameter validation and error responses
- ✅ Database integration for project creation
- ✅ Authentication bypass for testing
- ✅ Service integration mocking
- ✅ Edge cases and error scenarios

## Security Notes

⚠️ **Important**: All VCR cassettes have been verified to contain no real API keys. The VCR configuration automatically filters sensitive data.

## Dependencies

- `rspec-rails`: Testing framework
- `factory_bot_rails`: Test data factories
- `faker`: Realistic test data generation
- `vcr`: HTTP interaction recording
- `webmock`: HTTP request stubbing