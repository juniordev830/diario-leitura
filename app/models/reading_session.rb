class ReadingSession < ApplicationRecord
 belongs_to :book
 validates :ending_page, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
 validates :note, length: { maximum: 2000 }
end
