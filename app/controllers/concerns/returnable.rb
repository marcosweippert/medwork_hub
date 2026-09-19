module Returnable
  extend ActiveSupport::Concern

  included do
    helper_method :back_path, :originating_path, :path_with_return
  end

  def back_path(fallback)
    candidate = params[:return_to].presence
    internal_redirect_path?(candidate) ? candidate : fallback
  end

  def originating_path
    back_path(request.fullpath)
  end

  def path_with_return(path, return_to: originating_path)
    href = path.to_s
    return href unless internal_redirect_path?(return_to)

    uri = URI.parse(href)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query["return_to"] = return_to
    "#{uri.path}?#{query.to_query}"
  rescue URI::InvalidURIError
    href
  end

  def redirect_back_to(fallback, **options)
    request.format = :html if request.format.turbo_stream?
    options[:status] ||= :see_other unless request.get? || request.head?
    redirect_to back_path(fallback), **options
  end

  def internal_redirect_path?(path)
    return false if path.blank? || path.match?(/[\r\n]/)

    path.start_with?("/") && !path.start_with?("//") && !path.start_with?("/\\")
  end
end
