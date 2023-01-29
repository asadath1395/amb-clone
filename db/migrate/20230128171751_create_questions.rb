class CreateQuestions < ActiveRecord::Migration[7.0]
  def change
    create_table :questions do |t|
      t.string :question, null: false
      t.text :context, null: true
      t.text :answer, null: true
      t.integer :ask_count, default: 1
      t.string :audio_src_url, default: "", null: true

      t.timestamps
    end
  end
end
