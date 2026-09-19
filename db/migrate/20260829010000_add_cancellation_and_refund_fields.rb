class AddCancellationAndRefundFields < ActiveRecord::Migration[7.1]
  def change
    add_column :bookings, :cancelled_at, :datetime
    add_column :bookings, :cancellation_reason, :text
    add_column :bookings, :rescheduled_from, :datetime

    add_column :invoices, :refunded_at, :datetime
    add_column :invoices, :refunded_amount, :decimal, precision: 10, scale: 2, default: 0
    add_column :invoices, :refund_reason, :text
    add_column :invoices, :cancelled_at, :datetime
    add_column :invoices, :cancellation_reason, :text
    add_column :invoices, :cancellation_fee, :decimal, precision: 10, scale: 2, default: 0
  end
end
