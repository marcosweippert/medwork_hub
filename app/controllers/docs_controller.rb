class DocsController < ApplicationController
  before_action :require_clinic_staff

  PAGES = %w[
    visao-geral
    instalacao
    papeis
    modulos
    desenvolvimento
    producao
  ].freeze

  GROUPS = [
    { key: "getting_started", slugs: %w[visao-geral instalacao] },
    { key: "clinic", slugs: %w[papeis modulos] },
    { key: "build", slugs: %w[desenvolvimento producao] }
  ].freeze

  def index
    load_page("visao-geral")
    render :show
  end

  def show
    slug = params[:id].to_s
    unless PAGES.include?(slug)
      redirect_to docs_path, alert: t("docs.unknown")
      return
    end

    load_page(slug)
  end

  private

  def load_page(slug)
    @slug = slug
    markdown = Rails.root.join("docs", "#{slug}.md").read
    document = DocsMarkdown.document(markdown)
    html = rewrite_doc_links(document[:html]).sub(/\A\s*<h1\b[^>]*>.*?<\/h1>\s*/m, "")
    @body_html = helpers.sanitize(
      html,
      tags: %w[p h1 h2 h3 ul ol li a strong code pre div table thead tbody tr th td],
      attributes: %w[href class id]
    )
    @headings = document[:headings].reject { |heading| heading[:level] == 1 }
    @title = t("docs.pages.#{slug}.title")
    @index = PAGES.index(slug)
    @prev_slug = PAGES[@index - 1] if @index&.positive?
    @next_slug = PAGES[@index + 1]
  end

  def rewrite_doc_links(html)
    html.gsub(/href="([^"]+)"/) do
      href = Regexp.last_match(1)
      if href == "index" || href == "README"
        %(href="#{docs_path}")
      elsif PAGES.include?(href)
        %(href="#{doc_path(href)}")
      else
        %(href="#{href}")
      end
    end
  end
end
