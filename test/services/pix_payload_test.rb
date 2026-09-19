require "test_helper"

class PixPayloadTest < ActiveSupport::TestCase
  test "matches the BACEN static QR example CRC" do
    payload = [
      tlv("00", "01"),
      tlv("26", tlv("00", "br.gov.bcb.pix") + tlv("01", "123e4567-e12b-12d1-a456-426655440000")),
      tlv("52", "0000"),
      tlv("53", "986"),
      tlv("58", "BR"),
      tlv("59", "Fulano de Tal"),
      tlv("60", "BRASILIA"),
      tlv("62", tlv("05", "***"))
    ].join + "6304"

    assert_equal "1D3D", crc16(payload)
    assert_equal(
      "00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D",
      "#{payload}1D3D"
    )
  end

  test "builds a crc-checked emv payload with a normalized phone key" do
    code = PixPayload.build(
      key: "(11) 99999-8888",
      name: "MedWork Hub",
      city: "Sao Paulo",
      amount: 150,
      txid: "MW1TEST"
    )

    assert_includes code, "br.gov.bcb.pix"
    assert_includes code, "+5511999998888"
    refute_includes code, "(11) 99999-8888"
    payload, crc = code[0..-5], code[-4..]
    assert_equal crc, crc16(payload)
  end

  test "normalizes cpf email and random keys" do
    assert_equal "12345678909", PixKey.normalize("123.456.789-09")
    assert_equal "clinic@example.com", PixKey.normalize("Clinic@Example.com")
    assert_equal "123e4567-e12b-12d1-a456-426655440000", PixKey.normalize("123E4567E12B12D1A456426655440000")
    assert_equal "+5511999998888", PixKey.normalize("11999998888")
  end

  def tlv(id, value)
    "#{id}#{format('%02d', value.bytesize)}#{value}"
  end

  def crc16(payload)
    crc = 0xFFFF
    payload.bytes.each do |byte|
      crc ^= byte << 8
      8.times do
        crc = (crc & 0x8000).positive? ? ((crc << 1) ^ 0x1021) : (crc << 1)
        crc &= 0xFFFF
      end
    end
    format("%04X", crc)
  end
end
