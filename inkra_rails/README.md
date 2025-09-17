# Inkra Rails Backend

A Rails application that provides both API endpoints and web interface for the Inkra book writing platform. This app guides users through interviews to generate structured book outlines and transcripts.

## Features

### Web Interface
- 🏠 **Home Page**: Overview and navigation
- 📚 **Project Management**: Create, view, and manage writing projects
- 📝 **Outline Viewer**: See AI-generated book outlines with chapters and questions
- 📖 **Transcript Display**: View processed interview transcripts

### API Endpoints
- `POST /api/projects` - Create new project with topic
- `GET /api/projects/:id` - Get project details including outline
- `PATCH /api/projects/:id/outline` - Update outline (mark sections as omitted)
- `GET /api/projects/:id/transcript` - Get processed transcript
- `POST /api/projects/:id/audio/upload-request` - Request S3 upload URL
- `POST /api/projects/:id/audio/upload-complete` - Notify upload completion

## Setup

### Prerequisites
- Ruby 3.1.2
- PostgreSQL (installed via Homebrew)
- Rails 7.1.5

### Installation
```bash
# Install dependencies
bundle install

# Create and setup database
rails db:create
rails db:migrate

# Start the server
rails server
```

The application will be available at http://localhost:3000

### Database Schema
- **Projects**: Store book topics and status
- **Chapters**: Book outline chapters
- **Sections**: Chapter subsections
- **Questions**: Interview questions for each section
- **Audio Segments**: Audio upload metadata
- **Transcripts**: Processed transcript content

## API Usage

### Create Project
```bash
curl -X POST http://localhost:3000/api/projects \
  -H "Content-Type: application/json" \
  -d '{"project": {"initialTopic": "My startup journey"}}'
```

### Get Project Details
```bash
curl http://localhost:3000/api/projects/1
```

### Request Audio Upload
```bash
curl -X POST http://localhost:3000/api/projects/1/audio/upload-request \
  -H "Content-Type: application/json" \
  -d '{"fileName": "segment.m4a", "mimeType": "audio/x-m4a", "recordedDurationSeconds": 60, "questionId": "1"}'
```

## Development

### Running Tests
```bash
rails test
```

### Key Models
- `Project`: Main project with status tracking
- `Chapter`: Outline chapters with ordering
- `Section`: Chapter subsections
- `Question`: Interview questions
- `AudioSegment`: Audio file metadata
- `Transcript`: Processed interview content

## Production Notes

For production deployment, you'll need to configure:
- AWS S3 for audio file storage
- LLM service integration (OpenAI, Claude, etc.)
- Audio transcription service (AWS Transcribe, Whisper)
- Background job processing (Sidekiq, etc.)

## Technology Stack
- **Backend**: Ruby on Rails 7.1
- **Database**: PostgreSQL
- **Frontend**: HTML/ERB with Tailwind CSS
- **API**: RESTful JSON endpoints
- **Authentication**: None (prototype mode)

Built to complement the SwiftUI mobile app for complete Inkra experience.
