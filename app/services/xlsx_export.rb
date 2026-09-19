require "zlib"

class XlsxExport
  def self.build(sheet_name:, headers:, rows:)
    build_document(
      title: sheet_name,
      kind: "Report",
      clinic: "MedWork Hub",
      sections: [{ title: nil, headers: headers, rows: rows }]
    )
  end

  def self.build_document(document)
    new(document).pack
  end

  def initialize(document)
    @doc = document.deep_symbolize_keys
    @sheet_name = self.class.sanitize_sheet_name(@doc[:title])
    @strings = []
    @string_index = {}
  end

  def pack
    sheet = build_sheet
    files = {
      "[Content_Types].xml" => content_types,
      "_rels/.rels" => rels,
      "docProps/app.xml" => app_xml,
      "docProps/core.xml" => core_xml,
      "xl/workbook.xml" => workbook_xml,
      "xl/_rels/workbook.xml.rels" => workbook_rels,
      "xl/styles.xml" => styles_xml,
      "xl/sharedStrings.xml" => shared_strings_xml,
      "xl/worksheets/sheet1.xml" => sheet
    }
    ZipStore.pack(files)
  end

  def self.sanitize_sheet_name(name)
    cleaned = name.to_s.gsub(%r{[/\\*?:\[\]]}, " ").squeeze(" ").strip
    cleaned = "Report" if cleaned.blank?
    cleaned.truncate(31)
  end

  private

  def clinic
    @doc[:clinic].presence || "MedWork Hub"
  end

  def sections
    Array(@doc[:sections]).map { |section| section.deep_symbolize_keys }
  end

  def kpis
    Array(@doc[:kpis]).map { |kpi| kpi.deep_symbolize_keys }
  end

  def col_count
    counts = sections.map { |section| Array(section[:headers]).size }
    counts << 4
    [counts.max, 1].max
  end

  def build_sheet
    last_col = col_name(col_count - 1)
    xml = +%Q(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)
    xml << %Q(<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">)
    xml << %Q(<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>)
    xml << %Q(<dimension ref="A1:#{last_col}2000"/>)
    xml << %Q(<sheetViews><sheetView workbookViewId="0"><pane ySplit="5" topLeftCell="A6" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>)
    xml << %Q(<cols>)
    col_count.times do |index|
      width = index.zero? ? 28 : 16
      xml << %Q(<col min="#{index + 1}" max="#{index + 1}" width="#{width}" customWidth="1"/>)
    end
    xml << "</cols><sheetData>"

    row = 1
    xml << row_xml(row, [clinic.to_s.upcase], style: 3)
    row += 1
    xml << row_xml(row, [@doc[:title]], style: 2)
    row += 1
    meta = [@doc[:kind], @doc[:period], generated_line].compact_blank
    xml << row_xml(row, meta, style: 4)
    row += 1
    xml << row_xml(row, [], style: 0)
    row += 1

    kpis.each_slice(2) do |pair|
      values = pair.flat_map { |kpi| [kpi[:label], kpi[:value]] }
      xml << mixed_kpi_row(row, values)
      row += 1
    end

    sections.each do |section|
      if section[:title].present?
        row += 1
        xml << row_xml(row, [section[:title]], style: 5)
        row += 1
      end
      headers = Array(section[:headers])
      xml << row_xml(row, headers, style: 1) if headers.any?
      row += 1 if headers.any?
      Array(section[:rows]).each do |values|
        xml << row_xml(row, Array(values), style: 0)
        row += 1
      end
      if section[:totals]
        xml << row_xml(row, Array(section[:totals]), style: 6)
        row += 1
      end
    end

    xml << "</sheetData>"
    xml << %Q(<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>)
    xml << %Q(<pageSetup orientation="landscape" paperSize="9" fitToWidth="1" fitToHeight="0"/>)
    xml << %Q(<headerFooter><oddFooter>&amp;LInternal use — #{xml_escape(clinic)}&amp;RPage &amp;P of &amp;N</oddFooter></headerFooter>)
    xml << "</worksheet>"
  end

  def generated_line
    stamp = @doc[:generated_at].presence || Time.current
    stamp = stamp.strftime("%d/%m/%Y %H:%M") unless stamp.is_a?(String)
    by = @doc[:generated_by].presence
    [stamp, by].compact.join("  |  ")
  end

  def mixed_kpi_row(number, values)
    cells = values.each_with_index.map do |value, index|
      cell_xml(number, index, value, style: index.odd? ? 7 : 4)
    end.join
    %Q(<row r="#{number}" spans="1:#{[values.size, 1].max}">#{cells}</row>)
  end

  def row_xml(number, values, style:)
    cells = values.each_with_index.map { |value, index| cell_xml(number, index, value, style: style) }.join
    %Q(<row r="#{number}" spans="1:#{col_count}">#{cells}</row>)
  end

  def cell_xml(row, col, value, style:)
    ref = "#{col_name(col)}#{row}"
    style_attr = " s=\"#{style}\""
    normalized = normalize(value)
    if normalized.is_a?(Numeric)
      %Q(<c r="#{ref}"#{style_attr} t="n"><v>#{normalized}</v></c>)
    else
      %Q(<c r="#{ref}"#{style_attr} t="s"><v>#{intern_string(normalized)}</v></c>)
    end
  end

  def normalize(value)
    case value
    when nil then ""
    when Integer then value
    when Float then value.finite? ? value : value.to_s
    when BigDecimal then value.to_s("F").include?(".") ? value.to_f : value.to_i
    when TrueClass, FalseClass then value ? 1 : 0
    when Date then value.strftime("%Y-%m-%d")
    when Time, DateTime, ActiveSupport::TimeWithZone then value.strftime("%Y-%m-%d %H:%M")
    else
      sanitize_text(value)
    end
  end

  def sanitize_text(value)
    value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      .gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/, "")
      .tr("–—", "-")
  end

  def intern_string(text)
    key = text.to_s
    @string_index.fetch(key) do
      @string_index[key] = @strings.size
      @strings << key
      @string_index[key]
    end
  end

  def col_name(index)
    name = +""
    n = index + 1
    while n.positive?
      n, rem = (n - 1).divmod(26)
      name.prepend((65 + rem).chr)
    end
    name
  end

  def content_types
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
        <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
      </Types>
    XML
  end

  def rels
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
        <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
      </Relationships>
    XML
  end

  def workbook_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <workbookPr/>
        <sheets>
          <sheet name="#{xml_escape(@sheet_name)}" sheetId="1" r:id="rId1"/>
        </sheets>
        <calcPr calcId="0"/>
      </workbook>
    XML
  end

  def workbook_rels
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
      </Relationships>
    XML
  end

  def styles_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <fonts count="5">
          <font><sz val="11"/><color rgb="FF1F2933"/><name val="Calibri"/></font>
          <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>
          <font><b/><sz val="18"/><color rgb="FF1C3A61"/><name val="Calibri"/></font>
          <font><sz val="10"/><color rgb="FF5B6573"/><name val="Calibri"/></font>
          <font><b/><sz val="11"/><color rgb="FF1C3A61"/><name val="Calibri"/></font>
        </fonts>
        <fills count="5">
          <fill><patternFill patternType="none"/></fill>
          <fill><patternFill patternType="gray125"/></fill>
          <fill><patternFill patternType="solid"><fgColor rgb="FF1C3A61"/><bgColor rgb="FF1C3A61"/></patternFill></fill>
          <fill><patternFill patternType="solid"><fgColor rgb="FFE8ECF2"/><bgColor rgb="FFE8ECF2"/></patternFill></fill>
          <fill><patternFill patternType="solid"><fgColor rgb="FFF7F8FA"/><bgColor rgb="FFF7F8FA"/></patternFill></fill>
        </fills>
        <borders count="2">
          <border/>
          <border>
            <left style="thin"><color rgb="FFD5DBE3"/></left>
            <right style="thin"><color rgb="FFD5DBE3"/></right>
            <top style="thin"><color rgb="FFD5DBE3"/></top>
            <bottom style="thin"><color rgb="FFD5DBE3"/></bottom>
          </border>
        </borders>
        <cellStyleXfs count="1"><xf/></cellStyleXfs>
        <cellXfs count="8">
          <xf xfId="0" borderId="1" applyBorder="1"/>
          <xf xfId="0" fontId="1" fillId="2" borderId="1" applyFont="1" applyFill="1" applyBorder="1"/>
          <xf xfId="0" fontId="2" applyFont="1"/>
          <xf xfId="0" fontId="3" applyFont="1"/>
          <xf xfId="0" fontId="3" applyFont="1"/>
          <xf xfId="0" fontId="4" applyFont="1"/>
          <xf xfId="0" fontId="4" fillId="3" borderId="1" applyFont="1" applyFill="1" applyBorder="1"/>
          <xf xfId="0" fontId="4" fillId="4" applyFont="1" applyFill="1"/>
        </cellXfs>
      </styleSheet>
    XML
  end

  def shared_strings_xml
    xml = +%Q(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)
    xml << %Q(<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="#{@strings.size}" uniqueCount="#{@strings.size}">)
    @strings.each do |text|
      space = text.match?(/\A\s|\s\z/) ? ' xml:space="preserve"' : ""
      xml << "<si><t#{space}>#{xml_escape(text)}</t></si>"
    end
    xml << "</sst>"
  end

  def app_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
        <Application>MedWork Hub</Application>
      </Properties>
    XML
  end

  def core_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <dc:title>#{xml_escape(@doc[:title])}</dc:title>
        <dc:creator>#{xml_escape(clinic)}</dc:creator>
        <dcterms:created xsi:type="dcterms:W3CDTF">#{Time.current.utc.xmlschema}</dcterms:created>
      </cp:coreProperties>
    XML
  end

  def xml_escape(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
  end

  class ZipStore
    UTF8_FLAG = 0x0800

    def self.pack(files)
      entries = []
      offset = 0
      io = +"".b

      files.each do |name, content|
        data = content.to_s.encode(Encoding::UTF_8).b
        compressed = deflate(data)
        crc = Zlib.crc32(data)
        local = local_header(name, data.bytesize, compressed.bytesize, crc)
        io << local << compressed
        entries << { name: name, crc: crc, compressed: compressed.bytesize, original: data.bytesize, offset: offset }
        offset += local.bytesize + compressed.bytesize
      end

      central = +"".b
      entries.each { |entry| central << central_header(entry) }
      io << central
      io << end_of_central(entries.size, central.bytesize, offset)
      io
    end

    def self.deflate(data)
      z = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS)
      compressed = z.deflate(data, Zlib::FINISH)
      z.close
      compressed
    end

    def self.local_header(name, original, compressed, crc)
      encoded = name.encode("UTF-8").b
      [0x04034b50, 20, UTF8_FLAG, 8, 0, 0, crc, compressed, original, encoded.bytesize, 0].pack("VvvvvvVVVvv") + encoded
    end

    def self.central_header(entry)
      encoded = entry[:name].encode("UTF-8").b
      [
        0x02014b50, 20, 20, UTF8_FLAG, 8, 0, 0, entry[:crc], entry[:compressed], entry[:original],
        encoded.bytesize, 0, 0, 0, 0, 0, entry[:offset]
      ].pack("VvvvvvvVVVvvvvvVV") + encoded
    end

    def self.end_of_central(count, size, offset)
      [0x06054b50, 0, 0, count, count, size, offset, 0].pack("VvvvvVVv")
    end
  end
end
