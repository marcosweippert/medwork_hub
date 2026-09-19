module ReportBuilding
  extend ActiveSupport::Concern

  included do
    helper_method :analytical?, :report_view, :volume_tone
  end

  private

  def assign_report_view
    @report_view = params[:view].to_s == "detail" ? "detail" : "summary"
  end

  def report_view
    @report_view || (params[:view].to_s == "detail" ? "detail" : "summary")
  end

  def analytical?
    report_view == "detail"
  end

  def report_layout
    params[:print].present? ? "print" : "application"
  end

  def parse_date(value, fallback)
    value.present? ? Date.parse(value) : fallback
  rescue Date::Error, ArgumentError
    fallback
  end

  def occupancy_average
    rooms = Room.all
    return 0 if rooms.empty?

    (rooms.sum { |room| room.occupancy_on(Date.current) } / rooms.size.to_f).round
  end

  def report_snapshot
    month = Time.current.beginning_of_month..Time.current.end_of_month
    received = Invoice.where.not(paid_at: nil).where(paid_at: month).sum(:amount).to_d
    refunded = Invoice.where.not(refunded_at: nil).where(refunded_at: month).sum(:refunded_amount).to_d
    {
      occupancy: occupancy_average,
      revenue: received - refunded,
      overdue: Invoice.where(status: "overdue").sum(:amount).to_d,
      waitlist: WaitlistEntry.open.count,
      bounced: OutboundEmail.where(status: "bounced").where("sent_at >= ?", Time.zone.today.beginning_of_month).count
    }
  end

  def report_catalog
    snap = @snapshot || report_snapshot
    overdue_count = Invoice.where(status: "overdue").count
    [
      {
        title: "Operations",
        items: [
          { name: "Occupancy", path: occupancy_reports_path, hint: "Weekly heat map by room", stat: "#{snap[:occupancy]}%", detail: "today" },
          { name: "Room usage", path: rooms_reports_path, hint: "Hours booked and average occupancy", stat: Room.count, detail: "rooms" },
          { name: "Occupancy forecast", path: forecast_reports_path, hint: "Next 8 weeks of holds" },
          { name: "Peak hours", path: peak_hours_reports_path, hint: "When rooms are busiest" },
          { name: "Room blocks", path: blocks_reports_path, hint: "Closed slots and weekly blocks", stat: RoomBlock.count, detail: "blocks" },
          { name: "Bookings", path: bookings_reports_path, hint: "Volume by status, room and type", stat: Booking.holding.count, detail: "active holds" },
          { name: "Cancellations", path: cancellations_reports_path, hint: "Cancelled slots and fees" },
          { name: "Waitlist", path: waitlist_reports_path, hint: "Queue, offers and conversions", stat: snap[:waitlist], detail: "open" }
        ]
      },
      {
        title: "Finance",
        items: [
          { name: "Revenue", path: revenue_reports_path, hint: "Received, refunded and net collected", stat: helpers.number_to_currency(snap[:revenue], precision: 0), detail: "this month" },
          { name: "Receivables", path: receivables_reports_path, hint: "Open and overdue invoices", stat: helpers.number_to_currency(Invoice.open_or_overdue.sum(:amount), precision: 0), detail: "outstanding" },
          { name: "Aging", path: aging_reports_path, hint: "Overdue invoices by days past due", stat: overdue_count, detail: "overdue" }
        ]
      },
      {
        title: "People",
        items: [
          { name: "Professionals", path: professionals_reports_path, hint: "Hours billed and receivables", stat: Professional.count, detail: "active" },
          { name: "Patients", path: patients_reports_path, hint: "Caseload and clinical notes", stat: Patient.count, detail: "records" }
        ]
      },
      {
        title: "Communications",
        items: [
          { name: "Emails", path: emails_reports_path, hint: "Sent, failed and returned messages", stat: snap[:bounced], detail: "returned this month" },
          { name: "Activity", path: activity_reports_path, hint: "Audit actions by user and record", stat: AuditEvent.where("created_at >= ?", Time.zone.today.beginning_of_day).count, detail: "today" }
        ]
      }
    ]
  end

  def flatten_catalog(groups)
    groups.flat_map do |group|
      group[:items].map { |item| item.merge(group: group[:title]) }
    end
  end

  def volume_tone(value, max)
    return "heat-0" if value.to_i.zero? || max.to_i.zero?

    ratio = value.to_f / max
    return "heat-high" if ratio >= 0.7
    return "heat-mid" if ratio >= 0.35

    "heat-low"
  end

  def load_revenue
    @from = parse_date(params[:from], Date.current.beginning_of_month - 5.months)
    @to = parse_date(params[:to], Date.current)
    period = @from.beginning_of_day..@to.end_of_day
    invoices = Invoice.all
    invoices = invoices.where(room_id: params[:room_id]) if params[:room_id].present?
    invoices = invoices.where(professional_id: params[:professional_id]) if params[:professional_id].present?

    @months = []
    cursor = @from.beginning_of_month
    while cursor <= @to
      month_period = cursor.beginning_of_day..cursor.end_of_month.end_of_day
      received = invoices.where.not(paid_at: nil).where(paid_at: month_period).sum(:amount)
      refunded = invoices.where.not(refunded_at: nil).where(refunded_at: month_period).sum(:refunded_amount)
      @months << {
        month: cursor,
        received: received,
        refunded: refunded,
        net: received.to_d - refunded.to_d,
        paid: received.to_d - refunded.to_d,
        open: invoices.where(status: "open").where(created_at: month_period).sum(:amount),
        overdue: invoices.where(status: "overdue").where(created_at: month_period).sum(:amount)
      }
      cursor = cursor.next_month.beginning_of_month
    end

    received = invoices.where.not(paid_at: nil).where(paid_at: period).sum(:amount)
    refunded = invoices.where.not(refunded_at: nil).where(refunded_at: period).sum(:refunded_amount)
    @by_room = invoices.where.not(paid_at: nil).where(paid_at: period).joins(:room).group("rooms.name").sum(:amount)
    @refunded_by_room = invoices.where.not(refunded_at: nil).where(refunded_at: period).joins(:room).group("rooms.name").sum(:refunded_amount)
    @by_professional = invoices.where.not(paid_at: nil).where(paid_at: period)
      .joins(professional: :user).group("users.name").sum(:amount)
    @refunded_by_professional = invoices.where.not(refunded_at: nil).where(refunded_at: period)
      .joins(professional: :user).group("users.name").sum(:refunded_amount)
    @totals = {
      received: invoices.where.not(paid_at: nil).where(paid_at: period).sum(:amount),
      refunded: invoices.where.not(refunded_at: nil).where(refunded_at: period).sum(:refunded_amount),
      open: invoices.where(status: "open").sum(:amount),
      overdue: invoices.where(status: "overdue").sum(:amount)
    }
    @totals[:paid] = @totals[:received].to_d - @totals[:refunded].to_d
    @totals[:net] = @totals[:paid]
    outstanding = @totals[:received].to_d + @totals[:open].to_d + @totals[:overdue].to_d
    @collection_rate = outstanding.positive? ? ((@totals[:received].to_d / outstanding) * 100).round : 0
    @rooms = Room.order(:name)
    @professionals = Professional.includes(:user)
    @max_month = @months.map { |row| [row[:received].to_d, row[:refunded].to_d].max }.max.to_f
    @max_month = 1 if @max_month <= 0
    if analytical?
      @detail_invoices = invoices.includes(:room, professional: :user)
        .where("paid_at BETWEEN :s AND :e OR refunded_at BETWEEN :s AND :e", s: period.begin, e: period.end)
        .order(Arel.sql("COALESCE(paid_at, refunded_at) DESC"))
        .limit(1000)
    end
  end

  def load_professionals_report
    scope = Professional.includes(:user, :invoices, bookings: :invoice).order(:id)
    scope = scope.where(id: params[:professional_id]) if params[:professional_id].present?
    @only_delinquent = params[:delinquent] == "1"
    @rows = scope.filter_map do |professional|
      next if @only_delinquent && !professional.delinquent?

      bookings = professional.bookings
      {
        professional: professional,
        reserved_hours: bookings.select { |booking| booking.calendar_status == :reserved }.sum(&:duration_hours),
        occupied_hours: bookings.select { |booking| booking.calendar_status == :occupied }.sum(&:duration_hours),
        billed: professional.invoices.sum { |invoice| invoice.amount.to_d },
        paid: professional.invoices.select { |invoice| invoice.status == "paid" }.sum { |invoice| invoice.collected_amount },
        overdue: professional.invoices.select { |invoice| invoice.status == "overdue" }.sum { |invoice| invoice.amount.to_d },
        delinquent: professional.delinquent?
      }
    end
    @rows.sort_by! { |row| -row[:overdue].to_d }
    @professionals = Professional.includes(:user)
    return unless analytical?

    ids = @rows.map { |row| row[:professional].id }
    @detail_invoices = Invoice.includes(:room, professional: :user).where(professional_id: ids).order(due_date: :desc).limit(1000)
  end

  def load_receivables
    scope = Invoice.includes(:room, professional: :user, bookings: :room)
    scope = scope.where(professional_id: params[:professional_id]) if params[:professional_id].present?
    @open = scope.where(status: "open").order(:due_date)
    @overdue = scope.where(status: "overdue").order(:due_date)
    @open_total = @open.sum(:amount)
    @overdue_total = @overdue.sum(:amount)
    @professionals = Professional.includes(:user)
  end

  def days_overdue(invoice)
    return 0 if invoice.due_date.blank?

    [(Date.current - invoice.due_date).to_i, 0].max
  end

  def average_occupancy(room, from, to)
    days = (from..to).to_a.reject { |day| room.schedule_for(day).blank? }
    return 0 if days.empty?

    (days.sum { |day| room.occupancy_on(day) } / days.size.to_f).round
  end

  def period_label(from = @from, to = @to)
    return unless from && to

    "#{from.strftime("%d/%m/%Y")} - #{to.strftime("%d/%m/%Y")}"
  end

  def money(value)
    helpers.number_to_currency(value)
  end

  def room_net_rows(received_hash, refunded_hash)
    names = (received_hash.keys + refunded_hash.keys).uniq
    names.sort_by { |name| -(received_hash[name].to_d - refunded_hash[name].to_d) }.map do |name|
      received = received_hash[name].to_d
      refunded = refunded_hash[name].to_d
      [name, received, refunded, received - refunded]
    end
  end

  def invoice_detail_row(invoice)
    [
      invoice.id,
      invoice.professional.display_name,
      invoice.room&.name,
      invoice.status,
      invoice.amount,
      invoice.paid_at,
      invoice.refunded_amount
    ]
  end

  def clinic_name
    Setting.current.clinic_name.presence || "MedWork Hub"
  end

  def export_report(title:, filename:, period: nil, kpis: [], sections: [])
    document = {
      title: title,
      kind: analytical? ? "Analytical report" : "Synthetic report",
      clinic: clinic_name,
      period: period,
      generated_at: Time.current,
      generated_by: current_user&.display_name || "System",
      kpis: kpis,
      sections: sections
    }
    respond_to do |format|
      format.html
      format.xlsx do
        send_data XlsxExport.build_document(document),
                  filename: "#{filename}.xlsx",
                  type: Mime[:xlsx],
                  disposition: "attachment"
      end
      format.pdf do
        send_data PdfExport.build_document(document),
                  filename: "#{filename}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end
end
