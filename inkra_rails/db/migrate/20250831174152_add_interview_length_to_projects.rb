class AddInterviewLengthToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :interview_length, :string
    add_column :projects, :question_count, :integer
  end
end
