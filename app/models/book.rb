class Book < ApplicationRecord
 has_many :reading_sessions, dependent: :destroy
 validates :title, presence: true, length: { maximum: 160 }
 validates :total_pages, numericality: { only_integer: true, greater_than: 0 }
 validates :current_page, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
 validate :pages_in_bounds
 def pages_in_bounds
  return if total_pages.nil?
  errors.add(:current_page, "não pode ultrapassar o total") if current_page.to_i > total_pages
  errors.add(:goal_pages, "deve ficar entre 1 e o total") if goal_pages && (goal_pages < 1 || goal_pages > total_pages)
 end
 def progress_percent
  (current_page.to_f / total_pages * 100).round(1)
 end
end
