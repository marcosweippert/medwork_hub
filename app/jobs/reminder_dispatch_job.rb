class ReminderDispatchJob < ApplicationJob
  queue_as :mailers

  def perform
    ClinicMaintenanceJob.perform_now
    ReminderDispatch.call
  end
end
