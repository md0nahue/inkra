# Interview Questions Navigator

A beautiful Sinatra web application for navigating and exploring transformative interview questions from various personal development books.

## Features

- **Organized Structure**: Questions are organized by book source and interview tracks
- **Easy Navigation**: Browse through different tracks and questions with a clean UI
- **Responsive Design**: Works well on desktop and mobile devices
- **Beautiful UI**: Modern, gradient-based design with smooth animations

## Installation

1. Make sure you have Ruby installed (version 2.7 or higher)
2. Install dependencies:
   ```bash
   bundle install
   ```

## Usage

### Start the Application

Run the application using the provided script:
```bash
./start.sh
```

Or directly with:
```bash
bundle exec ruby app.rb
```

The application will be available at: http://localhost:4567

### Navigation Structure

- **Home Page**: Shows all available book collections
- **Book View**: Displays all interview tracks for a selected book
- **Track View**: Shows all 20 questions for a specific interview track

## Data Structure

The interview questions are stored in `interview_questions.yaml` and organized as follows:
- Multiple book sources (e.g., "The Courage to Be Disliked", "The Artist's Way", etc.)
- Each book contains multiple interview tracks (5-15 tracks)
- Each track contains exactly 20 thought-provoking questions
- Each track has a title and optional description

## Files

- `app.rb` - Main Sinatra application
- `interview_questions.yaml` - All interview questions data
- `views/` - ERB templates for HTML pages
- `public/css/style.css` - Styling for the application
- `parse_questions.rb` - Script to parse questions from text file

## Customization

You can easily add more questions by editing the `interview_questions.yaml` file following the existing structure.

## Tech Stack

- **Ruby** with **Sinatra** web framework
- **ERB** for templating
- **CSS3** for styling with gradients and animations
- **YAML** for data storage