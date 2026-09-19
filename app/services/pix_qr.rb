require "rqrcode"

class PixQr
  def self.svg(payload, size: 180)
    new(payload, size: size).svg
  end

  def initialize(payload, size: 180)
    @payload = payload.to_s
    @size = size.to_i
  end

  def svg
    return if @payload.blank?

    svg = RQRCode::QRCode.new(@payload, level: :m, mode: :byte).as_svg(
      offset: 12,
      fill: "ffffff",
      color: "111111",
      shape_rendering: "crispEdges",
      module_size: 3,
      standalone: true,
      use_path: true,
      viewbox: true,
      svg_attributes: {
        width: @size,
        height: @size,
        role: "img",
        "aria-label" => "PIX QR Code"
      }
    )
    svg.sub(/\A<\?xml[^>]*\?>\s*/i, "")
  end
end
