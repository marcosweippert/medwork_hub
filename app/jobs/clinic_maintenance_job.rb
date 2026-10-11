class ClinicMaintenanceJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform
    Invoice.expire_overdue!
    Ticket.auto_close_stale!
  end
end
