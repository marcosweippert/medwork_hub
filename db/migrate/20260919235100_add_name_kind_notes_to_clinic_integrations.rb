class AddNameKindNotesToClinicIntegrations < ActiveRecord::Migration[7.1]
  NAMES = {
    "smtp" => "SMTP",
    "pix" => "PIX",
    "whatsapp" => "WhatsApp",
    "calendar" => "Calendário",
    "n8n" => "n8n",
    "webhooks" => "Webhooks",
    "zapier" => "Zapier",
    "google_calendar" => "Google Calendar",
    "slack" => "Slack"
  }.freeze

  def up
    add_column :clinic_integrations, :name, :string
    add_column :clinic_integrations, :kind, :string
    add_column :clinic_integrations, :notes, :text

    say_with_time "backfill integration name and kind" do
      execute <<~SQL
        UPDATE clinic_integrations
        SET kind = provider,
            name = COALESCE(#{name_sql}, initcap(replace(provider, '_', ' ')))
      SQL
    end

    change_column_null :clinic_integrations, :name, false
    change_column_null :clinic_integrations, :kind, false
    add_index :clinic_integrations, :kind
  end

  def down
    remove_index :clinic_integrations, :kind
    remove_column :clinic_integrations, :notes
    remove_column :clinic_integrations, :kind
    remove_column :clinic_integrations, :name
  end

  private

  def name_sql
    pairs = NAMES.map { |provider, name| "WHEN '#{provider}' THEN #{quote(name)}" }.join(" ")
    "CASE provider #{pairs} END"
  end
end
