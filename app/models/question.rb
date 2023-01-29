class Question < ApplicationRecord
  validates :question, length: { maximum: 140 }, presence: true
  validates :answer, length: { maximum: 1000 }, presence: true 
  validates :audio_src_url, length: { maximum: 255 } 
end
