require "test_helper"
require "zlib"

class XlsxExportTest < ActiveSupport::TestCase
  test "writes cell references and shared strings that Excel can open" do
    data = XlsxExport.build(
      sheet_name: "Aging",
      headers: %w[Bucket Professional Amount Due],
      rows: [["1-7", "João Pereira", BigDecimal("150.50"), Date.new(2026, 8, 1)]]
    )

    assert data.start_with?("PK".b)
    files = unzip(data)
    sheet = files.fetch("xl/worksheets/sheet1.xml")
    assert_includes sheet, 'r="A1"'
    assert_includes sheet, 't="s"'
    assert_includes files.fetch("[Content_Types].xml"), "sharedStrings"
    assert_includes files.fetch("xl/sharedStrings.xml"), "Joao Pereira".then { |_| "João Pereira" }
    assert_includes files.fetch("xl/sharedStrings.xml"), "1-7"
  end

  test "pdf export starts with a pdf header" do
    data = PdfExport.build(title: "Aging", headers: %w[Bucket Amount], rows: [["1-7", 150]])
    assert data.start_with?("%PDF-1.4")
    assert_includes data, "%%EOF"
    assert_includes data, "Aging"
    assert_includes data, "Page 1 of 1"
  end

  test "document export includes title kind and section" do
    data = XlsxExport.build_document(
      title: "Bookings",
      kind: "Analytical report",
      clinic: "Clinic One",
      period: "01/09/2026 - 19/09/2026",
      kpis: [{ label: "Total", value: 12 }],
      sections: [{ title: "Records", headers: %w[Professional Room], rows: [["Ana", "Room A"]] }]
    )
    files = unzip(data)
    sheet = files.fetch("xl/worksheets/sheet1.xml")
    strings = files.fetch("xl/sharedStrings.xml")
    assert_includes strings, "Bookings"
    assert_includes strings, "Analytical report"
    assert_includes strings, "Records"
    assert_includes sheet, 's="1"'

    pdf = PdfExport.build_document(
      title: "Bookings",
      kind: "Synthetic report",
      clinic: "Clinic One",
      period: "September 2026",
      kpis: [{ label: "Total", value: "12" }],
      sections: [{ title: "By status", headers: %w[Status Count], rows: [["Confirmed", 4]] }]
    )
    assert pdf.start_with?("%PDF-1.4")
    assert_includes pdf, "Synthetic report"
    assert_includes pdf, "By status"
  end

  def unzip(data)
    files = {}
    offset = 0
    while data[offset, 4] == [0x04034b50].pack("V")
      _sig, _ver, _flag, method, _t, _d, _crc, compressed, original, name_len, extra_len =
        data[offset, 30].unpack("VvvvvvVVVvv")
      name = data[offset + 30, name_len]
      payload = data[offset + 30 + name_len + extra_len, compressed]
      files[name] = method == 8 ? inflate(payload) : payload
      offset += 30 + name_len + extra_len + compressed
    end
    files
  end

  def inflate(payload)
    z = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    out = z.inflate(payload)
    z.finish
    z.close
    out
  end
end
