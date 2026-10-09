class CreateAsks < ActiveRecord::Migration[8.1]
  def change
    create_table :asks, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.text   :whats_going_on, null: false
      t.string :asking_for,     null: false
      t.date   :moment_on
      t.string :vocabulary,     null: false
      t.string :visibility,     null: false

      t.timestamps null: false
    end
  end
end
