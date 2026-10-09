class CreateAskDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :ask_drafts, id: :uuid do |t|
      t.references :ask, type: :uuid, null: false, foreign_key: true
      t.string   :status, null: false, default: "pending"
      t.text     :gemini_raw
      t.string   :failure_reason
      t.datetime :generated_at

      t.string :title
      t.text   :body
      t.text   :what_changed
      t.string :moment_name
      t.date   :moment_on
      t.jsonb  :practical_help_ideas, null: false, default: []
      t.text   :outcome_question
      t.jsonb  :outcome_answers,      null: false, default: []
      t.jsonb  :privacy_flags,        null: false, default: []

      t.timestamps null: false
    end
    add_index :ask_drafts, :status
  end
end
