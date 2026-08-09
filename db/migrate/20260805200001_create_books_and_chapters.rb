class CreateBooksAndChapters < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :title
      t.string :author
      t.string :narrator
      t.text :description
      t.string :source, default: "librivox"
      t.string :source_identifier
      t.string :source_url
      t.integer :full_duration_seconds      # runtime of the whole work
      t.integer :audio_duration_seconds     # duration of the stitched file we built
      t.string :status, default: "pending", null: false
      t.text :error_message
      t.string :slug

      t.timestamps
    end
    add_index :books, :slug, unique: true
    add_index :books, :source_identifier

    create_table :chapters do |t|
      t.references :book, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :title
      t.string :source_url
      t.float :duration_seconds
      t.bigint :size_bytes
      t.boolean :included, default: false, null: false  # part of the stitched file?

      t.timestamps
    end
    add_index :chapters, [ :book_id, :position ], unique: true
  end
end
