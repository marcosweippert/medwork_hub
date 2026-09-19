class PdfExport
  PORTRAIT = [595, 842].freeze
  LANDSCAPE = [842, 595].freeze
  MARGIN = 40
  FONT_SIZE = 8.5
  ROW_H = 16
  TITLE_H = 18

  def self.build(title:, headers:, rows:, subtitle: nil, meta: nil, landscape: nil)
    build_document(
      title: title,
      kind: "Report",
      clinic: nil,
      period: subtitle,
      generated_at: Time.current,
      generated_by: nil,
      kpis: Array(meta).map { |line| { label: line, value: "" } },
      sections: [{ title: nil, headers: headers, rows: rows }],
      landscape: landscape
    )
  end

  def self.build_document(document)
    new(document).render
  end

  def initialize(document)
    @doc = document.deep_symbolize_keys
    @title = stringify(@doc[:title])
    @kind = stringify(@doc[:kind].presence || "Report")
    @clinic = stringify(@doc[:clinic].presence || clinic_name)
    @period = stringify(@doc[:period])
    @generated = (@doc[:generated_at].presence || Time.current)
    @generated = @generated.strftime("%d/%m/%Y %H:%M") unless @generated.is_a?(String)
    @generated_by = stringify(@doc[:generated_by].presence || "MedWork Hub")
    @kpis = Array(@doc[:kpis])
    @sections = Array(@doc[:sections]).map { |section| normalize_section(section) }
    header_count = @sections.map { |section| Array(section[:headers]).size }.max.to_i
    @landscape = @doc.key?(:landscape) && !@doc[:landscape].nil? ? @doc[:landscape] : header_count >= 7
    @page_w, @page_h = @landscape ? LANDSCAPE : PORTRAIT
    @objects = []
  end

  def render
    pages = paginate
    font_id = add_object("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
    bold_id = add_object("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
    content_ids = pages.each_with_index.map do |items, index|
      add_object(stream_object(page_content(items, index + 1, pages.size)))
    end
    page_ids = content_ids.map do |content_id|
      add_object(
        "<< /Type /Page /Parent PLACEHOLDER 0 R /MediaBox [0 0 #{@page_w} #{@page_h}] " \
        "/Contents #{content_id} 0 R /Resources << /Font << /F1 #{font_id} 0 R /F2 #{bold_id} 0 R >> >> >>"
      )
    end
    pages_id = add_object("<< /Type /Pages /Count #{page_ids.size} /Kids [#{page_ids.map { |id| "#{id} 0 R" }.join(" ")}] >>")
    page_ids.each { |page_id| @objects[page_id - 1] = @objects[page_id - 1].sub("PLACEHOLDER", pages_id.to_s) }
    catalog_id = add_object("<< /Type /Catalog /Pages #{pages_id} 0 R >>")
    assemble(catalog_id)
  end

  private

  def clinic_name
    Setting.current.clinic_name.presence || "MedWork Hub"
  rescue StandardError
    "MedWork Hub"
  end

  def normalize_section(section)
    section = section.deep_symbolize_keys
    headers = Array(section[:headers]).map { |value| stringify(value) }
    rows = Array(section[:rows]).map { |row| Array(row).map { |value| stringify(value) } }
    totals = section[:totals] ? Array(section[:totals]).map { |value| stringify(value) } : nil
    { title: stringify(section[:title]).presence, headers: headers, rows: rows, totals: totals }
  end

  def paginate
    items = document_items
    pages = []
    current = []
    used = 0
    budget = @page_h - MARGIN - 96 - 24
    items.each do |item|
      height = item_height(item)
      if current.any? && used + height > budget
        pages << current
        current = []
        used = 0
        if item[:type] == :row && item[:headers]
          header_item = { type: :thead, headers: item[:headers], title: item[:section] }
          current << header_item
          used += item_height(header_item)
        end
      end
      current << item
      used += height
    end
    pages << current if current.any?
    pages = [[{ type: :empty }]] if pages.empty?
    pages
  end

  def document_items
    items = []
    @kpis.each_slice(2) { |pair| items << { type: :kpis, pair: pair } }
    @sections.each do |section|
      items << { type: :section, text: section[:title] } if section[:title]
      next if section[:headers].blank? && section[:rows].blank?

      items << { type: :thead, headers: section[:headers], title: section[:title] }
      section[:rows].each { |row| items << { type: :row, values: row, headers: section[:headers], section: section[:title] } }
      items << { type: :totals, values: section[:totals], headers: section[:headers] } if section[:totals]
    end
    items
  end

  def item_height(item)
    case item[:type]
    when :section then TITLE_H + 8
    when :kpis then 20
    else ROW_H
    end
  end

  def page_content(items, page, pages)
    ops = []
    band_h = 64
    ops << fill_rect(0, @page_h - band_h, @page_w, band_h, 0.15, 0.23, 0.38)
    ops << text_op("/F1", 8, MARGIN, @page_h - 18, @clinic.upcase, 0.75, 0.82, 0.92)
    ops << text_op("/F2", 16, MARGIN, @page_h - 38, @title, 1, 1, 1)
    ops << text_op("/F1", 9, MARGIN, @page_h - 54, @kind, 0.85, 0.89, 0.95)
    right = "#{@generated}  |  #{@generated_by}"
    ops << text_op("/F1", 8, @page_w - MARGIN - text_width(right, 8), @page_h - 18, right, 0.75, 0.82, 0.92)
    y = @page_h - band_h - 16
    if @period.present?
      ops << text_op("/F1", 9, MARGIN, y, "Period: #{@period}", 0.25, 0.29, 0.36)
      y -= 14
    end
    stripe = 0
    items.each do |item|
      case item[:type]
      when :kpis
        ops.concat(draw_kpis(item[:pair], y))
        y -= 20
      when :section
        y -= 4
        ops << text_op("/F2", 11, MARGIN, y, item[:text], 0.15, 0.23, 0.38)
        y -= TITLE_H
        stripe = 0
      when :thead
        prepare_table(item[:headers])
        ops << fill_rect(MARGIN, y - 4, @page_w - (MARGIN * 2), ROW_H, 0.15, 0.23, 0.38)
        ops.concat(draw_row(item[:headers], y, "/F2", header: true))
        y -= ROW_H
        stripe = 0
      when :row
        prepare_table(item[:headers]) if @headers != item[:headers]
        ops << fill_rect(MARGIN, y - 4, @page_w - (MARGIN * 2), ROW_H, 0.96, 0.97, 0.98) if stripe.odd?
        ops.concat(draw_row(item[:values], y, "/F1"))
        y -= ROW_H
        stripe += 1
      when :totals
        prepare_table(item[:headers])
        ops << fill_rect(MARGIN, y - 4, @page_w - (MARGIN * 2), ROW_H, 0.91, 0.93, 0.96)
        ops.concat(draw_row(item[:values], y, "/F2"))
        y -= ROW_H
      end
    end
    ops << stroke_line(MARGIN, MARGIN + 10, @page_w - MARGIN, MARGIN + 10, 0.85, 0.88, 0.92)
    ops << text_op("/F1", 8, MARGIN, MARGIN - 6, "Internal use  |  #{@clinic}", 0.45, 0.5, 0.58)
    ops << text_op("/F1", 8, @page_w - MARGIN - 78, MARGIN - 6, "Page #{page} of #{pages}", 0.45, 0.5, 0.58)
    ops.join("\n")
  end

  def draw_kpis(pair, y)
    width = (@page_w - (MARGIN * 2) - 12) / 2.0
    pair.each_with_index.map do |kpi, index|
      x = MARGIN + (index * (width + 12))
      label = stringify(kpi[:label] || kpi["label"])
      value = stringify(kpi[:value] || kpi["value"])
      [
        fill_rect(x, y - 6, width, 18, 0.96, 0.97, 0.98),
        text_op("/F1", 8, x + 6, y + 2, clip(label, width - 90), 0.4, 0.45, 0.5),
        text_op("/F2", 10, x + width - 8 - text_width(value, 10), y + 1, clip(value, 80), 0.15, 0.23, 0.38)
      ]
    end.flatten
  end

  def prepare_table(headers)
    @headers = Array(headers)
    usable_w = @page_w - (MARGIN * 2)
    count = [@headers.size, 1].max
    weights = Array.new(count, 1.0)
    weights[0] = 1.6
    weights[-1] = 0.95 if count > 2
    total = weights.sum.to_f
    @col_w = weights.map { |weight| usable_w * (weight / total) }
    @col_x = []
    cursor = MARGIN.to_f
    @col_w.each do |width|
      @col_x << cursor
      cursor += width
    end
    @align_right = @headers.each_index.map { |index| numeric_header?(@headers[index]) }
  end

  def numeric_header?(header)
    header.to_s.match?(/amount|paid|open|overdue|hours|avg|fee|total|billed|count|%|days|received|refund|net|notes|bookings|patients|occ/i)
  end

  def draw_row(values, y, font, header: false)
    r, g, b = header ? [1.0, 1.0, 1.0] : [0.15, 0.18, 0.22]
    Array(values).each_with_index.map do |value, index|
      next if @col_w[index].nil?

      width = @col_w[index] - 8
      text = clip(stringify(value), width)
      x = if @align_right[index] && !header
            @col_x[index] + @col_w[index] - 6 - text_width(text, FONT_SIZE)
          else
            @col_x[index] + 5
          end
      text_op(font, FONT_SIZE, x, y, text, r, g, b)
    end.compact
  end

  def fill_rect(x, y, w, h, r, g, b)
    "#{format('%.3f %.3f %.3f', r, g, b)} rg #{format('%.2f %.2f %.2f %.2f', x, y, w, h)} re f"
  end

  def stroke_line(x1, y1, x2, y2, r, g, b)
    "#{format('%.3f %.3f %.3f', r, g, b)} RG 0.4 w #{format('%.2f %.2f m %.2f %.2f l S', x1, y1, x2, y2)}"
  end

  def text_op(font, size, x, y, text, r, g, b)
    <<~OPS.strip
      BT
      #{format('%.3f %.3f %.3f', r, g, b)} rg
      #{font} #{size} Tf
      1 0 0 1 #{format('%.2f', x)} #{format('%.2f', y)} Tm
      #{pdf_string(text)} Tj
      ET
    OPS
  end

  def text_width(text, size)
    text.to_s.length * size * 0.48
  end

  def clip(text, width)
    max_chars = [(width / (FONT_SIZE * 0.48)).floor, 4].max
    text.length > max_chars ? "#{text[0, max_chars - 1]}..." : text
  end

  def stringify(value)
    raw = case value
          when nil then ""
          when Date then value.strftime("%d/%m/%Y")
          when Time, DateTime, ActiveSupport::TimeWithZone then value.strftime("%d/%m/%Y %H:%M")
          when Integer then value.to_s
          when Float, BigDecimal then format_number(value)
          else value.to_s.tr("–—", "-")
          end
    I18n.transliterate(raw).gsub(/[^\x20-\x7E]/, "?")
  end

  def format_number(value)
    number = value.to_d
    return number.to_i.to_s if number == number.to_i && number.abs < 10_000

    parts = format("%.2f", number).split(".")
    parts[0] = parts[0].reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    parts.join(".")
  end

  def pdf_string(text)
    "(" + text.to_s.gsub("\\", "\\\\").gsub("(", "\\(").gsub(")", "\\)") + ")"
  end

  def stream_object(content)
    data = content.to_s.encode("ASCII", invalid: :replace, undef: :replace, replace: "?")
    payload = "#{data}\n"
    "<< /Length #{payload.bytesize} >>\nstream\n#{payload}endstream"
  end

  def add_object(body)
    @objects << body.to_s
    @objects.size
  end

  def assemble(catalog_id)
    io = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n".b
    offsets = [0]
    @objects.each_with_index do |body, index|
      offsets << io.bytesize
      io += "#{index + 1} 0 obj\n#{body}\nendobj\n".b
    end
    xref_pos = io.bytesize
    xref = +"xref\n0 #{@objects.size + 1}\n"
    xref << "0000000000 65535 f \n"
    offsets[1..].each { |offset| xref << format("%010d 00000 n \n", offset) }
    xref << "trailer\n<< /Size #{@objects.size + 1} /Root #{catalog_id} 0 R >>\n"
    xref << "startxref\n#{xref_pos}\n%%EOF\n"
    io + xref.b
  end
end
