class AddTemplateFieldsToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :is_template, :boolean, default: false
    add_column :projects, :template_name, :string
    add_column :projects, :template_description, :text
    add_index :projects, :is_template
  end
end
