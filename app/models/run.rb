class Run < ActiveRecord::Base
  belongs_to :contestant
  belongs_to :heat

  validates :contestant_id, presence: true
  validates :heat_id,       presence: true
  validates :lane,          presence: true

  def set_time(time)
    update_attributes! time: time
  end

  # Round times to 3 decimal places
  def time
    self[:time].try :round, 3
  end
end