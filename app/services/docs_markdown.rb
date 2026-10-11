require "cgi"

class DocsMarkdown
  def self.render(source)
    document(source)[:html]
  end

  def self.document(source)
    new(source.to_s).to_document
  end

  def initialize(source)
    @source = source.gsub("\r\n", "\n")
    @headings = []
    @slugs = Hash.new(0)
  end

  def to_html
    to_document[:html]
  end

  def to_document
    html = blocks.map { |block| render_block(block) }.join("\n")
    { html: html, headings: @headings }
  end

  private

  def blocks
    chunks = []
    fence = nil
    buffer = []
    @source.each_line do |line|
      if fence
        if line.strip.start_with?("```")
          chunks << { type: :code, lang: fence, text: buffer.join }
          buffer = []
          fence = nil
        else
          buffer << line
        end
        next
      end

      if line.strip.start_with?("```")
        chunks << { type: :text, text: buffer.join } if buffer.any?
        buffer = []
        fence = line.strip.delete_prefix("```").strip
        next
      end

      buffer << line
    end
    chunks << { type: :code, lang: fence, text: buffer.join } if fence
    chunks << { type: :text, text: buffer.join } if buffer.any? && fence.nil?
    chunks
  end

  def render_block(block)
    return %(<pre class="docs-pre"><code>#{escape(block[:text].to_s.rstrip)}</code></pre>) if block[:type] == :code

    render_text_blocks(block[:text].to_s)
  end

  def render_text_blocks(text)
    html = []
    para = []
    table = []
    list = nil

    flush_para = lambda do
      next if para.empty?
      html << "<p>#{inline(para.join(" ").strip)}</p>" unless para.join.strip.empty?
      para = []
    end
    flush_table = lambda do
      next if table.empty?
      html << render_table(table)
      table = []
    end
    flush_list = lambda do
      next unless list
      tag = list[:ordered] ? "ol" : "ul"
      items = list[:items].map { |item| "<li>#{inline(item)}</li>" }.join
      html << "<#{tag}>#{items}</#{tag}>"
      list = nil
    end

    text.each_line do |raw|
      line = raw.rstrip
      if line.match?(/^\|.+\|$/)
        flush_para.call
        flush_list.call
        table << line
        next
      end
      flush_table.call

      if (match = line.match(/\A\s*[-*]\s+(.+)\z/))
        flush_para.call
        list ||= { ordered: false, items: [] }
        list = { ordered: false, items: [] } if list[:ordered]
        list[:items] << match[1]
        next
      end
      if (match = line.match(/\A\s*\d+\.\s+(.+)\z/))
        flush_para.call
        list ||= { ordered: true, items: [] }
        list = { ordered: true, items: [] } unless list[:ordered]
        list[:items] << match[1]
        next
      end
      flush_list.call

      if line.blank?
        flush_para.call
        next
      end
      if (match = line.match(/\A(\#{1,3})\s+(.+)\z/))
        flush_para.call
        level = match[1].length
        text = match[2]
        id = heading_id(text)
        @headings << { id: id, text: text, level: level }
        html << %(<h#{level} id="#{id}">#{inline(text)}</h#{level}>)
        next
      end
      para << line
    end
    flush_table.call
    flush_list.call
    flush_para.call
    html.join("\n")
  end

  def render_table(rows)
    rows = rows.reject { |row| row.match?(/^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?$/) }
    return "" if rows.empty?

    cells = rows.map { |row| row.split("|").map(&:strip).reject(&:blank?) }
    head = cells.shift
    body = cells
    thead = "<thead><tr>#{head.map { |cell| "<th>#{inline(cell)}</th>" }.join}</tr></thead>"
    tbody = "<tbody>#{body.map { |row| "<tr>#{row.map { |cell| "<td>#{inline(cell)}</td>" }.join}</tr>" }.join}</tbody>"
    %(<div class="docs-table-wrap"><table class="docs-table">#{thead}#{tbody}</table></div>)
  end

  def inline(text)
    html = escape(text.to_s)
    html.gsub!(/`([^`]+)`/, '<code>\1</code>')
    html.gsub!(/\[([^\]]+)\]\(([^)]+)\)/) do
      label = Regexp.last_match(1)
      href = rewrite_href(Regexp.last_match(2))
      %(<a href="#{escape(href)}">#{label}</a>)
    end
    html.gsub!(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
    html
  end

  def heading_id(text)
    base = text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
    base = base.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    base = "section" if base.blank?
    @slugs[base] += 1
    @slugs[base] == 1 ? base : "#{base}-#{@slugs[base]}"
  end

  def rewrite_href(href)
    path = href.to_s.strip
    return path if path.start_with?("http://", "https://", "#", "mailto:")

    slug = File.basename(path.sub(/\A\.\.\//, ""), ".md")
    slug = "index" if slug == "README" || path.include?("README")
    slug
  end

  def escape(text)
    CGI.escapeHTML(text.to_s)
  end
end
