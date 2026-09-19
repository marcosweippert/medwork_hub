class AddTicketQueueSettings < ActiveRecord::Migration[7.1]
  def change
    add_reference :settings, :ticket_default_assignee, foreign_key: { to_table: :users }
    add_column :settings, :ticket_auto_close_days, :integer, null: false, default: 0
  end
end
