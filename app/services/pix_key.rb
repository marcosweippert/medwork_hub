class PixKey
  UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  EMAIL = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
  PHONE = /\A\+55\d{10,11}\z/
  CPF = /\A\d{11}\z/
  CNPJ = /\A\d{14}\z/
  CNPJ_ALNUM = /\A[0-9A-Z]{14}\z/

  def self.normalize(raw)
    key = raw.to_s.strip
    return "" if key.blank?

    return key.downcase if key.include?("@")

    compact = key.gsub(/\s+/, "")
    uuid = uuid_from(compact)
    return uuid if uuid

    digits = compact.gsub(/\D/, "")
    return phone_from(digits) if phone_input?(compact, digits)

    alnum = compact.gsub(/[^A-Za-z0-9]/, "").upcase
    return alnum if alnum.match?(CNPJ_ALNUM) && alnum.match?(/[A-Z]/)
    return digits if digits.length == 14
    return digits if digits.length == 11

    key
  end

  def self.valid?(raw)
    key = normalize(raw)
    key.match?(EMAIL) || key.match?(UUID) || key.match?(PHONE) || key.match?(CPF) ||
      key.match?(CNPJ) || key.match?(CNPJ_ALNUM)
  end

  def self.uuid_from(value)
    candidate = value.downcase
    return candidate if candidate.match?(UUID)

    hex = value.delete("-")
    return unless hex.match?(/\A[0-9a-f]{32}\z/i)

    hex = hex.downcase
    "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
  end

  def self.phone_input?(compact, digits)
    return false if compact.match?(/\A\d{3}\.\d{3}\.\d{3}-?\d{2}\z/)
    return false if compact.match?(/\A\d{2}\.\d{3}\.\d{3}\/?[\dA-Z]{4}-?[\dA-Z]{2}\z/i)
    return true if compact.start_with?("+")
    return true if compact.include?("(")
    return true if digits.length.between?(12, 13) && digits.start_with?("55")
    digits.length == 11 && digits[2] == "9"
  end

  def self.phone_from(digits)
    national = digits.sub(/\A55/, "")
    national = national.last(11)
    "+55#{national}"
  end
  private_class_method :uuid_from, :phone_input?, :phone_from
end
