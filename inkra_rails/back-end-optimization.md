# Back-end Optimization Recommendations

This document outlines recommendations for improving the performance and scalability of the Inkra Rails back-end. The analysis is based on a review of the database schema, Sidekiq logs, and application code.

## 1. Database Indexing

Adding appropriate database indexes is crucial for improving query performance. The following indexes are recommended:

**`projects` table:**

*   `add_index :projects, :status`
*   `add_index :projects, :template_name`
*   `add_index :projects, [:user_id, :last_accessed_at]`

**`audio_segments` table:**

*   `add_index :audio_segments, :upload_status`
*   `add_index :audio_segments, [:project_id, :created_at]`

**`transcripts` table:**

*   `add_index :transcripts, :status`

**`log_entries` table:**

*   `add_index :log_entries, :status`
*   `add_index :log_entries, [:user_id, :created_at]`

**`questions` table:**

*   `add_index :questions, [:section_id, :order]`

**`chapters` table:**

*   `add_index :chapters, [:project_id, :order]`

**`sections` table:**

*   `add_index :sections, [:chapter_id, :order]`

To add these indexes, you can generate a new migration and add the `add_index` calls listed above.

## 2. N+1 Query Prevention

N+1 queries are a common performance bottleneck in Rails applications. The following areas were identified as potential sources of N+1 queries:

**`ProjectsController#show`:**

The `show` action currently makes a separate query to load the `@transcript`. This can be avoided by eager loading the association in the `set_project` before_action.

**Recommendation:**

Modify `app/controllers/projects_controller.rb` as follows:

```ruby
def set_project
  @project = Project.includes(:transcript).find(params[:id])
end
```

**`ProjectsController#index`:**

The `index` action is currently not causing an N+1 query, but it's a common place for them to occur. If you need to display any associated data for each project on the index page (e.g., the number of chapters), be sure to use `includes` to avoid N+1 queries.

**Example:**

```ruby
# To display the number of chapters for each project
@projects = Project.includes(:chapters).order(created_at: :desc)
```

**`Api::ProjectsController#questions_with_responses`:**

This action loads all questions and then iterates over them to get the `audio_segments`. While `includes` is used, the `question.audio_segments.first` call within the loop can still lead to extra queries if not handled carefully.

**Recommendation:**

Create a hash of audio segments keyed by `question_id` to avoid N+1 queries.

```ruby
def questions_with_responses
  # ...
  questions_with_audio = @project.questions
                                .includes(:section => {:chapter => {}}, :audio_segments => {})
                                .order("sections.order, questions.order")

  audio_segments_by_question_id = questions_with_audio.flat_map(&:audio_segments).group_by(&:question_id)

  serialized_questions = questions_with_audio.map do |question|
    audio_response = (audio_segments_by_question_id[question.id] || []).first
    # ...
  end
  # ...
end
```

**`Api::ProjectsController#generate_stock_image_topics`:**

This action iterates through `selected_questions` and performs a query for each one to get the audio segment. This is a classic N+1 query.

**Recommendation:**

Load all the audio segments in a single query.

```ruby
def generate_stock_image_topics
  # ...
  audio_segments = @project.audio_segments.where(question_id: selected_questions).where.not(transcription_data: nil)
  transcription_texts = audio_segments.map do |segment|
    segment.transcription_data['text'] || segment.transcription_data[:text]
  end.compact
  # ...
end
```

## 3. Background Job Performance

The Sidekiq logs show that the `OutlineGenerationJob` enqueues a separate `PollyGenerationJob` for each question in a loop. This can be inefficient for large outlines.

**Recommendation:**

Use Sidekiq's `push_bulk` method to enqueue all `PollyGenerationJob` instances in a single call. This reduces the overhead of multiple `perform_async` calls.

**Example (in `OutlineGenerationJob`):**

```ruby
args = questions.map { |question| [question.id, { voice_id: 'Matthew', speech_rate: 100 }] }
PollyGenerationJob.perform_bulk(args)
```

This is also applicable to the `add_more_chapters` action in `Api::ProjectsController`.

## 4. Bulk Data Insertion and Updates

The `ProjectsController#create` and `Api::ProjectsController#add_more_chapters` actions use a loop to create chapters, sections, and questions. For large outlines, this can be slow.

**Recommendation:**

Use `insert_all` to bulk insert records for each model. This will perform a single SQL `INSERT` statement per model, which is significantly faster than creating records one by one.

**Example (in `generate_outline_for_project`):**

```ruby
# Create Chapters
chapter_rows = chapters_data.map { |d| d.slice(:title, :order).merge(project_id: project.id) }
Chapter.insert_all(chapter_rows)

# ... and so on for sections and questions
```

**`Api::ProjectsController#outline`:**

This action updates multiple records in a loop. This could be optimized by grouping the updates by model and using `update` on the relations.

**Recommendation:**

```ruby
def outline
  updates_by_type = params[:updates].group_by { |u| u.keys.first.gsub('_id', '') }

  updates_by_type.each do |type, updates|
    ids = updates.map { |u| u["#{type}_id"] }
    omitted_by_id = updates.index_by { |u| u["#{type}_id"] }

    model_class = type.classify.constantize
    records = @project.send(model_class.to_s.underscore.pluralize).where(id: ids)

    records.each do |record|
      record.update(omitted: omitted_by_id[record.id][:omitted])
    end
  end

  @project.update(last_modified_at: Time.current)

  render json: { message: 'Outline updated successfully' }
end
```