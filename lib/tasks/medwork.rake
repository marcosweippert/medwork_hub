namespace :medwork do
  desc "Expire overdue invoices and send booking/overdue reminder emails"
  task reminders: :environment do
    ReminderDispatchJob.perform_now
  end
end
