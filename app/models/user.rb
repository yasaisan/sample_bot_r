class User < ApplicationRecord
  validates :userId, presence: true
end
