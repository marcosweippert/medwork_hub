namespace :medwork do
  desc "Expire overdue invoices, close stale tickets, and send reminder emails"
  task reminders: :environment do
    ReminderDispatchJob.perform_now
  end
end
