class ReminderDispatchJob < ApplicationJob
  queue_as :mailers

  def perform
    Invoice.expire_overdue!
    ReminderDispatch.call
  end
end
