class InvoicePdf < PdfExport
  def self.render(invoice)
    new(invoice).render
  end

  def initialize(invoice)
    @invoice = invoice
    @policy = ClinicPolicy.summary
    @rows = line_rows
    @headers = %w[index date start end duration room type status value].map { |key| I18n.t("invoices.pdf_doc.columns.#{key}") }
    number = invoice.id.to_s.rjust(4, "0")
    super({
      title: I18n.t("invoices.pdf_doc.title", number: number),
      subtitle: invoice.professional.display_name,
      landscape: false
    })
    prepare_table(@headers)
    @align_right[-1] = true
  end

  private

  def line_rows
    @invoice.slot_lines.each.with_index(1).map do |row, index|
      [
        index,
        row[:start]&.strftime("%d/%m/%Y"),
        row[:start]&.strftime("%H:%M"),
        row[:end]&.strftime("%H:%M"),
        duration_label(row),
        row[:booking].room.name,
        billing_label(row[:booking].billing_type),
        I18n.t("statuses.#{row[:status]}", default: row[:status].to_s),
        money(row[:amount])
      ]
    end
  end

  def duration_label(row)
    return "—" unless row[:start] && row[:end]

    minutes = ((row[:end] - row[:start]) / 60).round
    hours = minutes / 60
    rest = minutes % 60
    return "#{minutes} min" if hours.zero?
    return "#{hours}h" if rest.zero?

    "#{hours}h #{rest.to_s.rjust(2, "0")}m"
  end

  def header_block_height
    176
  end

  def paginate
    available = @page_h - MARGIN - header_block_height - 168
    per_page = [[(available / ROW_H).floor, 16].min, 6].max
    chunks = Array(@rows).each_slice(per_page).to_a
    chunks = [[]] if chunks.empty?
    chunks
  end

  def column_weights
    [0.42, 1.15, 0.7, 0.7, 0.95, 1.35, 0.95, 1.2, 1.05]
  end

  def numeric_column?(index)
    index == @headers.size - 1
  end

  def billing_label(type)
    I18n.t("invoices.types.#{type}", default: type.to_s)
  end

  def billing_summary
    @invoice.bookings.map { |booking| billing_label(booking.billing_type) }.uniq.join(" / ").presence || "—"
  end

  def money(value)
    parts = format("%.2f", value.to_d).split(".")
    parts[0] = parts[0].reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
    parts.join(",")
  end

  def format_number(value)
    money(value)
  end

  def page_content(rows, page, pages)
    ops = []
    table_w = @page_w - (MARGIN * 2)
    band_h = 50
    ops << fill_rect(0, @page_h - band_h, @page_w, band_h, 0.11, 0.29, 0.56)
    ops << text_op("/F1", 9, MARGIN, @page_h - 18, @clinic, 1, 1, 1)
    ops << text_op("/F2", 16, MARGIN, @page_h - 38, @title, 1, 1, 1)
    ops << text_op("/F2", 10, @page_w - MARGIN - 110, @page_h - 28, I18n.t("statuses.#{@invoice.status}", default: @invoice.status.to_s).upcase, 0.85, 0.92, 1)

    y = @page_h - band_h - 14
    box_gap = 10
    box_w = (table_w - (box_gap * 2)) / 3.0
    box_h = 78
    boxes = [
      [
        I18n.t("invoices.bill_to"),
        stringify(@invoice.professional.display_name),
        stringify(Array(@invoice.professional.practice_area_labels).first(2).join(", ").presence || @invoice.professional.specialty.presence || I18n.t("invoices.professional_fallback")),
        I18n.t("invoices.pdf_doc.room", name: stringify(@invoice.room&.name || I18n.t("invoices.general")))
      ],
      [
        I18n.t("invoices.dates"),
        I18n.t("invoices.issued", date: @invoice.issued_on.strftime("%d/%m/%Y")),
        I18n.t("invoices.due", date: @invoice.due_date&.strftime("%d/%m/%Y") || "-"),
        @invoice.paid_at ? I18n.t("invoices.paid_at", time: @invoice.paid_at.strftime("%d/%m/%Y %H:%M")) : I18n.t("invoices.pdf_doc.payment_open")
      ],
      [
        I18n.t("invoices.pdf_doc.summary"),
        I18n.t("invoices.pdf_doc.slots", count: @invoice.slot_count, type: stringify(billing_summary)),
        I18n.t("invoices.pdf_doc.amounts", amount: money(@invoice.amount), refunded: money(@invoice.refunded_amount)),
        "#{@invoice.payable? ? I18n.t("invoices.amount_due") : I18n.t("invoices.net")} #{money(@invoice.net_amount)}"
      ]
    ]
    boxes.each_with_index do |box, index|
      x = MARGIN + (index * (box_w + box_gap))
      ops << fill_rect(x, y - box_h + 12, box_w, box_h, 0.95, 0.97, 0.99)
      ops << text_op("/F1", 7, x + 8, y + 2, box[0], 0.11, 0.29, 0.56)
      ops << text_op("/F2", 9, x + 8, y - 14, box[1].to_s[0, 42], 0.15, 0.18, 0.22)
      ops << text_op("/F1", 8, x + 8, y - 28, box[2].to_s[0, 48], 0.25, 0.3, 0.38)
      ops << text_op("/F1", 8, x + 8, y - 42, box[3].to_s[0, 48], 0.25, 0.3, 0.38)
    end

    y -= box_h + 8
    ops << text_op("/F1", 8, MARGIN, y, I18n.t("invoices.pdf_doc.slot_note", minutes: Room.slot_minutes, txid: stringify(@invoice.pix_txid.presence || "-")), 0.35, 0.42, 0.52)
    y -= 16

    ops << fill_rect(MARGIN, y - 5, table_w, ROW_H, 0.11, 0.29, 0.56)
    ops.concat(draw_row(@headers, y, "/F2", header: true))
    y -= ROW_H
    rows.each_with_index do |row, index|
      ops << fill_rect(MARGIN, y - 5, table_w, ROW_H, 0.96, 0.97, 0.98) if index.odd?
      ops.concat(draw_row(row, y, "/F1"))
      y -= ROW_H
    end
    ops << stroke_line(MARGIN, y + 4, MARGIN + table_w, y + 4, 0.85, 0.88, 0.92)

    if page == pages
      y -= 16
      totals = [
        [I18n.t("invoices.amount"), money(@invoice.amount)],
        ([I18n.t("invoices.refunded"), money(@invoice.refunded_amount)] if @invoice.refunded_amount.positive?),
        ([I18n.t("invoices.cancellation_fee"), money(@invoice.cancellation_fee)] if @invoice.cancellation_fee.positive?),
        [@invoice.payable? ? I18n.t("invoices.amount_due") : I18n.t("invoices.net"), money(@invoice.net_amount)]
      ].compact
      totals_w = 220
      totals_x = MARGIN + table_w - totals_w
      ops << fill_rect(totals_x, y - (totals.size * 16) + 10, totals_w, (totals.size * 16) + 8, 0.94, 0.96, 0.99)
      totals.each do |label, value|
        ops << text_op("/F1", 8, totals_x + 10, y, label, 0.25, 0.3, 0.38)
        ops << text_op("/F2", 9, totals_x + totals_w - 12 - text_width(value, 9), y, value, 0.15, 0.18, 0.22)
        y -= 16
      end
      y -= 10
      ops << text_op("/F2", 9, MARGIN, y, I18n.t("invoices.pdf_doc.policy_title"), 0.11, 0.29, 0.56)
      y -= 13
      ops << text_op("/F1", 8, MARGIN, y, I18n.t("invoices.pdf_doc.policy", hours: @policy[:free_hours], late: @policy[:late_percent], started: @policy[:started_percent]), 0.2, 0.25, 0.32)
      y -= 12
      ops << text_op("/F1", 8, MARGIN, y, I18n.t("invoices.pdf_doc.partial"), 0.2, 0.25, 0.32)
      if @invoice.notes.present?
        y -= 12
        ops << text_op("/F1", 8, MARGIN, y, I18n.t("invoices.pdf_doc.notes", notes: stringify(@invoice.notes.to_s.tr("\n", " ")[0, 140])), 0.35, 0.42, 0.52)
      end
    end

    ops << text_op("/F1", 8, MARGIN, MARGIN - 8, I18n.t("invoices.pdf_doc.generated", time: @generated, clinic: @clinic), 0.45, 0.5, 0.58)
    ops << text_op("/F1", 8, @page_w - MARGIN - 90, MARGIN - 8, I18n.t("invoices.pdf_doc.page", page: page, pages: pages), 0.45, 0.5, 0.58)
    ops.join("\n")
  end
end
