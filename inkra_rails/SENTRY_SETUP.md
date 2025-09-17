# Sentry Error Monitoring Setup

## Overview
This Rails application uses Sentry for error monitoring and performance tracking on the free tier (5,000 errors/month).

## Installation Complete
- ✅ Added `sentry-ruby` and `sentry-rails` gems to Gemfile
- ✅ Created Sentry initializer at `config/initializers/sentry.rb`

## Required Setup Steps

### 1. Create Sentry Account & Project
1. Go to [sentry.io](https://sentry.io) and create a free account
2. Create a new project and select "Rails" as the platform
3. Copy the DSN (Data Source Name) from the project settings

### 2. Configure Environment Variable
Add your Sentry DSN to your environment:

```bash
# For development (.env file or shell)
export SENTRY_DSN="https://your-dsn@sentry.io/project-id"

# For production (Heroku example)
heroku config:set SENTRY_DSN="https://your-dsn@sentry.io/project-id"
```

### 3. Install Gems
```bash
bundle install
```

### 4. Test Error Reporting
Create a test error in Rails console:
```ruby
# In rails console
Sentry.capture_message("Test message from VibeWriter Rails")

# Or trigger an actual error
raise "Test error for Sentry"
```

## Configuration Details

### Sampling Rates
- **Development**: 100% of transactions and profiles captured
- **Production**: 10% sampling to stay within free tier limits

### Filtered Data
- Health check requests (`/up`) are automatically filtered out
- Sensitive data filtering can be added to the `before_send` callback

### Release Tracking
- Automatically uses git commit SHA or Heroku slug commit as release version
- Helps track which deployments introduced errors

## Monitoring Usage
- Check your Sentry project dashboard for error counts
- Free tier limit: 5,000 errors/month
- Upgrade to paid plan if needed: $26/month for 50K errors

## Additional Features
- **Breadcrumbs**: Active Support and HTTP request logging enabled
- **Performance Monitoring**: Transaction tracing configured
- **Profiling**: CPU profiling enabled for performance insights

## Troubleshooting
- Verify `SENTRY_DSN` environment variable is set
- Check Rails logs for Sentry initialization messages
- Test with `Sentry.capture_message("test")` in Rails console