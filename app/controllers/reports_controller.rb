class ReportsController < ApplicationController
  include ReportBuilding
  layout :report_layout
  before_action :require_clinic_staff
  before_action :assign_report_view, except: :index

  def index
    @snapshot = report_snapshot
    @reports = flatten_catalog(report_catalog)
    if params[:q].present?
      needle = params[:q].to_s.downcase
      @reports = @reports.select { |item| "#{item[:name]} #{item[:hint]} #{item[:group]}".downcase.include?(needle) }
    end
  end

  def occupancy
    requested = parse_date(params[:week], Date.current)
    @week = requested.beginning_of_week(Setting.current.week_start_symbol)
    @days = 7.times.map { |offset| @week + offset }
    @rooms = Room.order(:name)
    @rooms = @rooms.where(id: params[:room_id]) if params[:room_id].present?
    @rows = @rooms.map do |room|
      daily = @days.map { |day| room.occupancy_on(day) }
      { room: room, daily: daily, average: (daily.sum / daily.size.to_f).round }
    end
    @clinic_average = @rows.any? ? (@rows.sum { |row| row[:average] } / @rows.size.to_f).round : 0
    heatmap = {
      title: "Weekly occupancy %",
      headers: ["Room", *@days.map { |day| day.strftime("%a %d/%m") }, "Average"],
      rows: @rows.map { |row| [row[:room].name, *row[:daily], row[:average]] }
    }
    detail = {
      title: "Daily occupancy",
      headers: ["Room", "Date", "Occupancy %"],
      rows: @rows.flat_map do |row|
        @days.each_with_index.map { |day, index| [row[:room].name, day, row[:daily][index]] }
      end
    }
    export_report(
      title: "Occupancy",
      filename: "occupancy-#{@week}",
      period: "Week of #{@week.strftime("%d/%m/%Y")}",
      kpis: [{ label: "Clinic average", value: "#{@clinic_average}%" }, { label: "Rooms", value: @rows.size }],
      sections: analytical? ? [detail, heatmap] : [heatmap]
    )
  end

  def revenue
    load_revenue
    summary = {
      title: "By month",
      headers: %w[Month Received Refunded Net Open Overdue],
      rows: @months.map { |row| [row[:month].strftime("%Y-%m"), row[:received], row[:refunded], row[:net], row[:open], row[:overdue]] }
    }
    by_room = {
      title: "By room",
      headers: %w[Room Received Refunded Net],
      rows: room_net_rows(@by_room, @refunded_by_room)
    }
    by_pro = {
      title: "By professional",
      headers: %w[Professional Received Refunded Net],
      rows: room_net_rows(@by_professional, @refunded_by_professional)
    }
    detail = {
      title: "Invoices",
      headers: ["Invoice", "Professional", "Room", "Status", "Amount", "Paid at", "Refunded"],
      rows: Array(@detail_invoices).map { |invoice| invoice_detail_row(invoice) }
    }
    export_report(
      title: "Revenue",
      filename: "revenue-#{@from}-#{@to}",
      period: period_label,
      kpis: [
        { label: "Received", value: money(@totals[:received]) },
        { label: "Refunded", value: money(@totals[:refunded]) },
        { label: "Net collected", value: money(@totals[:net]) },
        { label: "Open / overdue", value: money(@totals[:open].to_d + @totals[:overdue].to_d) }
      ],
      sections: analytical? ? [detail, summary, by_room, by_pro] : [summary, by_room, by_pro]
    )
  end

  def professionals
    load_professionals_report
    summary = {
      title: "Professionals",
      headers: ["Professional", "Reserved hours", "Occupied hours", "Billed", "Paid", "Overdue"],
      rows: @rows.map { |row| [row[:professional].display_name, row[:reserved_hours], row[:occupied_hours], row[:billed], row[:paid], row[:overdue]] }
    }
    detail = {
      title: "Invoices",
      headers: ["Invoice", "Professional", "Room", "Status", "Amount", "Due"],
      rows: Array(@detail_invoices).map { |invoice| [invoice.id, invoice.professional.display_name, invoice.room&.name, invoice.status, invoice.amount, invoice.due_date] }
    }
    export_report(
      title: "Professionals",
      filename: "professionals",
      kpis: [
        { label: "Professionals", value: @rows.size },
        { label: "Overdue total", value: money(@rows.sum { |row| row[:overdue].to_d }) }
      ],
      sections: analytical? ? [detail, summary] : [summary]
    )
  end

  def receivables
    load_receivables
    open_section = {
      title: "Open",
      headers: %w[Professional Room Amount Due],
      rows: @open.map { |invoice| [invoice.professional.display_name, invoice.room&.name, invoice.amount, invoice.due_date] },
      totals: ["Total", "", @open_total, ""]
    }
    overdue_section = {
      title: "Overdue",
      headers: %w[Professional Room Amount Due],
      rows: @overdue.map { |invoice| [invoice.professional.display_name, invoice.room&.name, invoice.amount, invoice.due_date] },
      totals: ["Total", "", @overdue_total, ""]
    }
    export_report(
      title: "Receivables",
      filename: "receivables",
      kpis: [
        { label: "Open", value: "#{money(@open_total)} (#{@open.size})" },
        { label: "Overdue", value: "#{money(@overdue_total)} (#{@overdue.size})" }
      ],
      sections: analytical? ? [open_section, overdue_section] : []
    )
  end

  def bookings
    @from = parse_date(params[:from], Date.current.beginning_of_month)
    @to = parse_date(params[:to], Date.current)
    scope = Booking.includes(:room, professional: :user).where(start_time: @from.beginning_of_day..@to.end_of_day)
    scope = scope.where(room_id: params[:room_id]) if params[:room_id].present?
    @by_status = scope.group(:status).count
    @by_room = scope.joins(:room).group("rooms.name").count
    @by_type = scope.group(:billing_type).count
    @bookings = scope.order(:start_time)
    @rooms = Room.order(:name)
    status_section = { title: "By status", headers: %w[Status Count], rows: @by_status.map { |status, count| [status.to_s.titleize, count] } }
    room_section = { title: "By room", headers: %w[Room Count], rows: @by_room.sort_by { |_, count| -count }.map { |name, count| [name, count] } }
    type_section = { title: "By type", headers: %w[Type Count], rows: @by_type.map { |type, count| [type.presence || "—", count] } }
    detail = {
      title: "Bookings",
      headers: %w[Professional Room Start End Type Status Amount],
      rows: @bookings.map { |booking| [booking.professional.display_name, booking.room.name, booking.start_time, booking.end_time, booking.billing_type, booking.status, booking.amount] }
    }
    export_report(
      title: "Bookings",
      filename: "bookings-#{@from}-#{@to}",
      period: period_label,
      kpis: @by_status.map { |status, count| { label: status.to_s.titleize.presence || "Blank", value: count } },
      sections: analytical? ? [detail, status_section, room_section, type_section] : [status_section, room_section, type_section]
    )
  end

  def cancellations
    @from = parse_date(params[:from], Date.current.beginning_of_month)
    @to = parse_date(params[:to], Date.current)
    @bookings = Booking.includes(:room, :invoice, professional: :user)
      .where(status: "cancelled")
      .where(cancelled_at: @from.beginning_of_day..@to.end_of_day)
      .order(cancelled_at: :desc)
    @fee_total = @bookings.sum { |booking| booking.invoice&.cancellation_fee.to_d }
    @count = @bookings.size
    detail = {
      title: "Cancellations",
      headers: %w[Professional Room Start Cancelled Fee],
      rows: @bookings.map { |booking| [booking.professional.display_name, booking.room.name, booking.start_time, booking.cancelled_at, booking.invoice&.cancellation_fee] },
      totals: ["Total", "", "", "", @fee_total]
    }
    export_report(
      title: "Cancellations",
      filename: "cancellations-#{@from}-#{@to}",
      period: period_label,
      kpis: [{ label: "Cancelled", value: @count }, { label: "Fees", value: money(@fee_total) }],
      sections: analytical? ? [detail] : []
    )
  end

  def aging
    overdue = Invoice.includes(:room, professional: :user).where(status: "overdue")
    overdue = overdue.where(professional_id: params[:professional_id]) if params[:professional_id].present?
    buckets = { "1-7" => 1..7, "8-15" => 8..15, "16-30" => 16..30, "31+" => 31..9_999 }
    @groups = buckets.map do |label, range|
      invoices = overdue.select { |invoice| range.cover?(days_overdue(invoice)) }
      { label: label, invoices: invoices, total: invoices.sum { |invoice| invoice.amount.to_d } }
    end
    @professionals = Professional.includes(:user)
    summary = {
      title: "Aging buckets",
      headers: ["Bucket", "Invoices", "Amount"],
      rows: @groups.map { |group| ["#{group[:label]} days", group[:invoices].size, group[:total]] }
    }
    details = @groups.map do |group|
      {
        title: "#{group[:label]} days",
        headers: %w[Professional Room Amount Due Days],
        rows: group[:invoices].map { |invoice| [invoice.professional.display_name, invoice.room&.name, invoice.amount, invoice.due_date, days_overdue(invoice)] },
        totals: ["Total", "", group[:total], "", ""]
      }
    end
    export_report(
      title: "Aging",
      filename: "aging",
      kpis: @groups.map { |group| { label: "#{group[:label]} days", value: "#{money(group[:total])} (#{group[:invoices].size})" } },
      sections: analytical? ? details + [summary] : [summary]
    )
  end

  def rooms
    @from = parse_date(params[:from], Date.current.beginning_of_week(Setting.current.week_start_symbol))
    @to = parse_date(params[:to], Date.current)
    range = @from.beginning_of_day..@to.end_of_day
    @rows = Room.order(:name).map do |room|
      bookings = room.bookings.visible_on_calendar.includes(professional: :user).where("start_time < ? AND end_time > ?", range.end, range.begin)
      hours = bookings.sum(&:duration_hours)
      { room: room, bookings: bookings.size, hours: hours, occupancy: average_occupancy(room, @from, @to), records: bookings }
    end
    @detail_bookings = @rows.flat_map { |row| row[:records].map { |booking| [booking, row[:room]] } } if analytical?
    summary = {
      title: "Room usage",
      headers: ["Room", "Bookings", "Hours", "Avg occupancy %"],
      rows: @rows.map { |row| [row[:room].name, row[:bookings], row[:hours], row[:occupancy]] }
    }
    detail = {
      title: "Holds in period",
      headers: %w[Room Professional Start End Hours Status],
      rows: Array(@detail_bookings).map { |booking, room| [room.name, booking.professional.display_name, booking.start_time, booking.end_time, booking.duration_hours, booking.status] }
    }
    export_report(
      title: "Room usage",
      filename: "room-usage-#{@from}-#{@to}",
      period: period_label,
      kpis: [{ label: "Rooms", value: @rows.size }, { label: "Holds", value: @rows.sum { |row| row[:bookings] } }],
      sections: analytical? ? [detail, summary] : [summary]
    )
  end

  def forecast
    start_on = Date.current.beginning_of_week(Setting.current.week_start_symbol)
    @weeks = 8.times.map { |offset| start_on + (offset * 7) }
    @rooms = Room.order(:name)
    @rooms = @rooms.where(id: params[:room_id]) if params[:room_id].present?
    @rows = @rooms.map do |room|
      weekly = @weeks.map { |week| average_occupancy(room, week, week + 6) }
      { room: room, weekly: weekly, average: weekly.any? ? (weekly.sum / weekly.size.to_f).round : 0 }
    end
    heatmap = {
      title: "8-week occupancy %",
      headers: ["Room", *@weeks.map { |week| week.strftime("%d/%m") }, "Average"],
      rows: @rows.map { |row| [row[:room].name, *row[:weekly], row[:average]] }
    }
    detail = {
      title: "Weekly occupancy",
      headers: ["Room", "Week starting", "Occupancy %"],
      rows: @rows.flat_map do |row|
        @weeks.each_with_index.map { |week, index| [row[:room].name, week, row[:weekly][index]] }
      end
    }
    export_report(
      title: "Occupancy forecast",
      filename: "forecast",
      period: "#{@weeks.first.strftime("%d/%m/%Y")} - #{(@weeks.last + 6).strftime("%d/%m/%Y")}",
      kpis: [{ label: "Rooms", value: @rows.size }, { label: "Weeks", value: @weeks.size }],
      sections: analytical? ? [detail, heatmap] : [heatmap]
    )
  end

  def peak_hours
    @from = parse_date(params[:from], Date.current.beginning_of_month)
    @to = parse_date(params[:to], Date.current)
    scope = Booking.where(start_time: @from.beginning_of_day..@to.end_of_day).where.not(status: "cancelled")
    scope = scope.where(room_id: params[:room_id]) if params[:room_id].present?
    raw = scope.group(Arel.sql("EXTRACT(DOW FROM start_time)::int"), Arel.sql("EXTRACT(HOUR FROM start_time)::int")).count
    @hours = (7..21).to_a
    start = Setting.current.week_start_symbol
    @dows = start == :monday ? [1, 2, 3, 4, 5, 6, 0] : [0, 1, 2, 3, 4, 5, 6]
    @dow_labels = { 0 => "Sun", 1 => "Mon", 2 => "Tue", 3 => "Wed", 4 => "Thu", 5 => "Fri", 6 => "Sat" }
    @grid = @dows.index_with { |dow| @hours.index_with { |hour| raw[[dow, hour]].to_i } }
    @max = raw.values.max.to_i
    @total = scope.count
    @rooms = Room.order(:name)
    @detail_bookings = scope.includes(:room, professional: :user).order(:start_time) if analytical?
    heatmap = {
      title: "Bookings by hour",
      headers: ["Day", *@hours.map { |hour| format("%02d:00", hour) }],
      rows: @dows.map { |dow| [@dow_labels[dow], *@hours.map { |hour| @grid[dow][hour] }] }
    }
    detail = {
      title: "Bookings",
      headers: %w[Professional Room Start Weekday Hour Status],
      rows: Array(@detail_bookings).map { |booking| [booking.professional.display_name, booking.room.name, booking.start_time, booking.start_time.strftime("%a"), booking.start_time.hour, booking.status] }
    }
    export_report(
      title: "Peak hours",
      filename: "peak-hours-#{@from}-#{@to}",
      period: period_label,
      kpis: [{ label: "Bookings", value: @total }, { label: "Busiest cell", value: @max }],
      sections: analytical? ? [detail, heatmap] : [heatmap]
    )
  end

  def blocks
    @blocks = RoomBlock.includes(:room).order(:starts_at)
    @blocks = @blocks.where("room_id = :id OR room_id IS NULL", id: params[:room_id]) if params[:room_id].present?
    @rooms = Room.order(:name)
    @one_off = @blocks.one_off.count
    @recurring = @blocks.recurring.count
    @clinic_wide = @blocks.count { |block| block.clinic_wide? }
    detail = {
      title: "Room blocks",
      headers: %w[Room Reason Recurring When Weekdays],
      rows: @blocks.map do |block|
        [
          block.room&.name || "Clinic",
          block.label,
          block.recurring? ? "yes" : "no",
          "#{block.starts_at.strftime("%d/%m %H:%M")}-#{block.ends_at.strftime("%H:%M")}",
          block.weekdays_label
        ]
      end
    }
    export_report(
      title: "Room blocks",
      filename: "room-blocks",
      kpis: [
        { label: "One-off", value: @one_off },
        { label: "Weekly", value: @recurring },
        { label: "Clinic-wide", value: @clinic_wide }
      ],
      sections: analytical? ? [detail] : []
    )
  end

  def waitlist
    scope = WaitlistEntry.includes(:room, professional: :user)
    scope = scope.where(room_id: params[:room_id]) if params[:room_id].present?
    @by_status = scope.group(:status).count
    @open_entries = scope.open.order(:starts_at)
    @by_room = scope.joins(:room).group("rooms.name").count
    @converted = scope.where(status: "booked").count
    @total = scope.count
    @rate = @total.positive? ? ((@converted.to_f / @total) * 100).round : 0
    @rooms = Room.order(:name)
    @entries = scope.order(:starts_at) if analytical?
    status_section = { title: "By status", headers: %w[Status Count], rows: @by_status.map { |status, count| [status.to_s.titleize, count] } }
    room_section = { title: "By room", headers: %w[Room Count], rows: @by_room.sort_by { |_, count| -count }.map { |name, count| [name, count] } }
    detail = {
      title: "Waitlist entries",
      headers: %w[Professional Room Start End Status],
      rows: Array(@entries || (analytical? ? [] : @open_entries)).map { |entry| [entry.professional.display_name, entry.room.name, entry.starts_at, entry.ends_at, entry.status] }
    }
    export_report(
      title: "Waitlist",
      filename: "waitlist",
      kpis: [
        { label: "Entries", value: @total },
        { label: "Converted", value: "#{@rate}%" },
        { label: "Open", value: @open_entries.size }
      ],
      sections: analytical? ? [detail, status_section, room_section] : [status_section, room_section]
    )
  end

  def patients
    scope = Patient.includes(:appointment_notes, :bookings, professional: :user)
    scope = scope.where(professional_id: params[:professional_id]) if params[:professional_id].present?
    @rows = Professional.includes(:user).order(:id).filter_map do |professional|
      patients = scope.select { |patient| patient.professional_id == professional.id }
      next if params[:professional_id].present? && patients.empty? && professional.id != params[:professional_id].to_i

      {
        professional: professional,
        patients: patients.size,
        notes: patients.sum { |patient| patient.appointment_notes.size },
        bookings: patients.sum { |patient| patient.bookings.size }
      }
    end
    @rows.reject! { |row| row[:patients].zero? } if params[:professional_id].blank?
    @total_patients = Patient.count
    @with_bookings = Patient.joins(:bookings).distinct.count
    @notes = AppointmentNote.count
    @professionals = Professional.includes(:user)
    @patients = scope.order(:name) if analytical?
    summary = {
      title: "By professional",
      headers: ["Professional", "Patients", "Notes", "Linked bookings"],
      rows: @rows.map { |row| [row[:professional].display_name, row[:patients], row[:notes], row[:bookings]] }
    }
    detail = {
      title: "Patients",
      headers: ["Patient", "Professional", "Contact", "Notes", "Bookings"],
      rows: Array(@patients).map { |patient| [patient.name, patient.professional.display_name, patient.contact, patient.appointment_notes.size, patient.bookings.size] }
    }
    export_report(
      title: "Patients",
      filename: "patients",
      kpis: [
        { label: "Patients", value: @total_patients },
        { label: "With bookings", value: @with_bookings },
        { label: "Notes", value: @notes }
      ],
      sections: analytical? ? [detail, summary] : [summary]
    )
  end

  def emails
    @from = parse_date(params[:from], Date.current.beginning_of_month)
    @to = parse_date(params[:to], Date.current)
    scope = OutboundEmail.where(sent_at: @from.beginning_of_day..@to.end_of_day)
    @by_status = scope.group(:status).count
    @by_kind = scope.group(:action_name).count
    @failed = scope.where(status: %w[failed bounced]).newest.limit(40)
    @totals = {
      sent: @by_status["sent"].to_i,
      failed: @by_status["failed"].to_i,
      bounced: @by_status["bounced"].to_i,
      total: scope.count
    }
    @emails = scope.newest.limit(500) if analytical?
    kind_section = { title: "By kind", headers: %w[Kind Count], rows: @by_kind.sort_by { |_, count| -count }.map { |kind, count| [kind.to_s.humanize, count] } }
    failed_section = {
      title: "Failed and returned",
      headers: %w[When To Status Reason],
      rows: @failed.map { |email| [email.sent_at, email.to_address, email.status, email.error_message] }
    }
    detail = {
      title: "Emails",
      headers: %w[When To Subject Kind Status Reason],
      rows: Array(@emails).map { |email| [email.sent_at, email.to_address, email.subject, email.kind_label, email.status, email.error_message] }
    }
    export_report(
      title: "Emails",
      filename: "emails-#{@from}-#{@to}",
      period: period_label,
      kpis: [
        { label: "Sent", value: @totals[:sent] },
        { label: "Failed", value: @totals[:failed] },
        { label: "Returned", value: @totals[:bounced] }
      ],
      sections: analytical? ? [detail, kind_section] : [kind_section, failed_section]
    )
  end

  def activity
    @from = parse_date(params[:from], Date.current.beginning_of_month)
    @to = parse_date(params[:to], Date.current)
    scope = AuditEvent.where(created_at: @from.beginning_of_day..@to.end_of_day)
    @by_action = scope.group(:action).count.sort_by { |_, count| -count }.first(12)
    @by_type = scope.group(:auditable_type).count
    @by_user = scope.left_joins(:user).group("COALESCE(users.name, users.email, 'System')").count.sort_by { |_, count| -count }.first(12)
    @total = scope.count
    @today = AuditEvent.where("created_at >= ?", Time.zone.today.beginning_of_day).count
    @events = scope.includes(:user).newest.limit(500) if analytical?
    action_section = { title: "Top actions", headers: %w[Action Count], rows: @by_action.map { |action, count| [action, count] } }
    user_section = { title: "By user", headers: %w[User Count], rows: @by_user.map { |name, count| [name, count] } }
    type_section = { title: "By record", headers: %w[Record Count], rows: @by_type.sort_by { |_, count| -count }.map { |type, count| [type.presence || "—", count] } }
    detail = {
      title: "Events",
      headers: %w[When User Action Record],
      rows: Array(@events).map { |event| [event.created_at, event.actor_name, event.action, event.record_name] }
    }
    export_report(
      title: "Activity",
      filename: "activity-#{@from}-#{@to}",
      period: period_label,
      kpis: [{ label: "Events", value: @total }, { label: "Today", value: @today }, { label: "Record types", value: @by_type.size }],
      sections: analytical? ? [detail, action_section, user_section, type_section] : [action_section, user_section, type_section]
    )
  end
end
