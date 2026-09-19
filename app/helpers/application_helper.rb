module ApplicationHelper
  def page_heading
    labels = {
      "dashboards" => "Dashboard",
      "professionals" => "Professionals",
      "patients" => "Patients",
      "bookings" => "Bookings",
      "rooms" => "Rooms",
      "invoices" => "Invoices",
      "reports" => "Reports",
      "users" => "Users",
      "settings" => "Settings",
      "waitlist_entries" => "Waitlist",
      "room_blocks" => "Room blocks",
      "audit_events" => "Audit log",
      "outbound_emails" => "Emails"
    }
    base = labels.fetch(controller_name, controller_name.titleize)
    return "#{base} calendar" if action_name == "calendar"
    return "Welcome email" if action_name == "edit_welcome"

    case action_name
    when "new" then "New #{base.singularize}"
    when "edit" then "Edit #{base.singularize}"
    when "show" then base.singularize
    else base
    end
  end

  def status_tag(status)
    return content_tag(:span, "—", class: "tag") if status.blank?

    mapping = {
      "refunded" => "t-used",
      "open" => "t-old",
      "paid" => "t-active",
      "overdue" => "t-unavail",
      "cancelled" => "t-used",
      "scheduled" => "t-info",
      "confirmed" => "t-unavail",
      "pending" => "t-old",
      "reserved" => "t-old",
      "occupied" => "t-unavail",
      "completed" => "t-new",
      "active" => "t-active",
      "paused" => "t-old",
      "expired" => "t-used",
      "waiting" => "t-old",
      "offered" => "t-info",
      "booked" => "t-active",
      "blocked" => "t-used",
      "sent" => "t-active",
      "failed" => "t-unavail",
      "bounced" => "t-unavail",
      "created" => "t-active",
      "updated" => "t-info",
      "deleted" => "t-unavail"
    }
    labels = { "pending" => "Reserved", "confirmed" => "Occupied", "bounced" => "Returned" }
    content_tag(:span, labels.fetch(status.to_s.downcase, status.to_s.titleize), class: "tag #{mapping.fetch(status.to_s.downcase, 't-info')}")
  end

  def nav_active?(path)
    if path == root_path
      current_page?(root_path)
    else
      request.path == path || request.path.start_with?("#{path}/")
    end
  end

  def nav_class(path)
    nav_active?(path) ? "nav-link is-active" : "nav-link"
  end

  def professional_field_tag(name, professionals, selected: nil, html: {})
    if professional_user? && current_professional
      data = (html[:data] || {}).merge(
        room_types: current_professional.allowed_room_types.join(",")
      )
      hidden_field_tag(name, current_professional.id, data: data) +
        tag.input(type: "text", class: "input", value: current_professional.display_name, disabled: true, autocomplete: "off")
    else
      select_tag name, professional_options(professionals, selected: selected), { class: "select" }.merge(html)
    end
  end

  def professional_options(professionals, include_blank: "Select professional", selected: nil)
    options = professionals.map do |professional|
      label = professional.delinquent? ? "#{professional.display_name} (overdue)" : professional.display_name
      html = { data: { room_types: professional.allowed_room_types.join(",") } }
      html[:disabled] = true if professional.delinquent?
      [label, professional.id, html]
    end
    options_for_select([[include_blank, ""]] + options, selected)
  end

  def room_options(rooms, selected: nil, include_blank: "Select room")
    options = rooms.map do |room|
      label = room.room_types.any? ? "#{room.name} · #{room.types_label}" : room.name
      [label, room.id, { data: { types: Array(room.room_types).join(","), hourly_rate: room.hourly_price } }]
    end
    options_for_select([[include_blank, ""]] + options, selected)
  end

  def weekday_options
    %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].each_with_index.map { |name, wday| [name, wday] }
  end

  def print_path_for(path)
    uri = URI.parse(path)
    params = Rack::Utils.parse_nested_query(uri.query.to_s)
    params["print"] = "1"
    "#{uri.path}?#{params.to_query}"
  end

  def filter_select(name, choices, selected: nil, include_blank: "All")
    select_tag name, options_for_select([[include_blank, ""]] + choices, selected), class: "select"
  end

  def action_btn(label, path, tone: "view", method: :get, confirm: nil, params: nil, frame: nil)
    css = "btn btn--chip btn--#{tone}"
    href = merge_query(path, params)
    data = {}
    data[:turbo_frame] = frame if frame
    if method.to_sym == :get
      link_to label, href, class: css, title: label, data: data.presence
    else
      data[:turbo_method] = method
      data[:turbo_confirm] = confirm if confirm
      link_to label, href, class: css, title: label, data: data
    end
  end

  def merge_query(path, extra)
    return path if extra.blank?

    uri = URI.parse(path.to_s)
    query = Rack::Utils.parse_nested_query(uri.query.to_s).merge(extra.to_h.stringify_keys)
    "#{uri.path}?#{query.to_query}"
  rescue URI::InvalidURIError
    path
  end

  def export_xlsx_path
    url_for(request.query_parameters.merge(format: :xlsx))
  end

  def export_pdf_path
    url_for(request.query_parameters.merge(format: :pdf))
  end

  def whatsapp_url(phone, text)
    digits = phone.to_s.gsub(/\D/, "")
    return if digits.blank?

    digits = "55#{digits}" unless digits.start_with?("55")
    "https://wa.me/#{digits}?text=#{ERB::Util.url_encode(text)}"
  end

  def clinic_policy
    ClinicPolicy.summary
  end

  def pix_qr_svg(payload, size: 180)
    svg = PixQr.svg(payload, size: size)
    return if svg.blank?

    svg.html_safe
  end

  def occupancy_tone(value)
    value = value.to_i
    return "heat-0" if value <= 0
    return "heat-low" if value < 35
    return "heat-mid" if value < 70

    "heat-high"
  end

  def invoice_slot_rows(invoice)
    invoice.slot_lines
  end

  def auditable_path_for(event)
    return if event.auditable_type.blank? || event.auditable_id.blank?

    case event.auditable_type
    when "Booking" then booking_path(event.auditable_id)
    when "Invoice" then invoice_path(event.auditable_id)
    when "User" then user_path(event.auditable_id)
    when "Professional" then professional_path(event.auditable_id)
    when "Room" then room_path(event.auditable_id)
    when "Patient" then patient_path(event.auditable_id)
    when "WaitlistEntry" then waitlist_entries_path
    when "RoomBlock" then room_blocks_path
    when "AppointmentNote"
      note = event.auditable
      note&.booking_id ? booking_path(note.booking_id) : nil
    end
  rescue StandardError
    nil
  end
end
