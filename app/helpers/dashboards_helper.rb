module DashboardsHelper
  def dashboard_greeting
    hour = Time.current.hour
    key = if hour < 12
            "dashboards.good_morning"
          elsif hour < 18
            "dashboards.good_afternoon"
          else
            "dashboards.good_evening"
          end
    t(key, name: current_user.name.to_s.split.first)
  end
end
