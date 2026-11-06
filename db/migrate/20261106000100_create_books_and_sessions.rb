class CreateBooksAndSessions < ActiveRecord::Migration[7.2]
 def change
  create_table :books do |t|
   t.string :title, null: false
   t.integer :total_pages, null: false
   t.integer :current_page, null: false, default: 0
   t.integer :goal_pages
   t.timestamps
  end
  create_table :reading_sessions do |t|
   t.references :book, null: false, foreign_key: true
   t.integer :ending_page, null: false
   t.text :note, null: false, default: ""
   t.timestamps
  end
 end
end
