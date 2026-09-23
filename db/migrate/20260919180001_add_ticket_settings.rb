class AddTicketSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :settings, :ticket_sla_urgent, :integer, null: false, default: 4
    add_column :settings, :ticket_sla_high, :integer, null: false, default: 8
    add_column :settings, :ticket_sla_medium, :integer, null: false, default: 24
    add_column :settings, :ticket_sla_low, :integer, null: false, default: 72
    add_column :settings, :ticket_sla_warn_hours, :integer, null: false, default: 4
    add_column :settings, :ticket_default_priority, :string, null: false, default: "medium"
    add_column :settings, :ticket_notify_staff, :boolean, null: false, default: true
    add_column :settings, :ticket_notify_requester, :boolean, null: false, default: true
  end
end
