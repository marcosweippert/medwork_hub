class PixPayload
  GUI = "br.gov.bcb.pix"
  ACCOUNT_MAX = 99

  def self.build(key:, name:, city:, amount:, txid:, description: nil)
    new(key: key, name: name, city: city, amount: amount, txid: txid, description: description).to_s
  end

  def initialize(key:, name:, city:, amount:, txid:, description: nil)
    @key = PixKey.normalize(key)
    @name = truncate(name.presence || "MedWork Hub", 25)
    @city = truncate(city.presence || "SAO PAULO", 15)
    @amount = format("%.2f", amount.to_d)
    @txid = sanitize_txid(txid)
    @description = fit_description(description)
  end

  def to_s
    payload = [
      tlv("00", "01"),
      tlv("26", merchant_account),
      tlv("52", "0000"),
      tlv("53", "986"),
      tlv("54", @amount),
      tlv("58", "BR"),
      tlv("59", @name),
      tlv("60", @city),
      tlv("62", additional_data)
    ].join
    payload_with_crc = "#{payload}6304"
    payload_with_crc + crc16(payload_with_crc)
  end

  private

  def merchant_account
    parts = [tlv("00", GUI), tlv("01", @key)]
    parts << tlv("02", @description) if @description
    parts.join
  end

  def additional_data
    tlv("05", @txid)
  end

  def tlv(id, value)
    "#{id}#{format('%02d', value.bytesize)}#{value}"
  end

  def ascii(text)
    I18n.transliterate(text.to_s).gsub(/[^A-Za-z0-9 ]/, "").squeeze(" ").strip
  end

  def truncate(text, length)
    ascii(text)[0, length]
  end

  def sanitize_txid(txid)
    cleaned = txid.to_s.gsub(/[^A-Za-z0-9]/, "")[0, 25]
    cleaned.presence || "***"
  end

  def fit_description(description)
    text = truncate(description, 72)
    return if text.blank?

    used = tlv("00", GUI).bytesize + tlv("01", @key).bytesize
    available = ACCOUNT_MAX - used - 4
    return if available < 1

    text[0, available]
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
