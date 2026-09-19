module Paginatable
  extend ActiveSupport::Concern

  def paginate(scope, per: 20)
    @page = [params[:page].to_i, 1].max
    @per_page = per
    counted = scope.except(:includes, :preload, :eager_load, :order, :select).count
    counted = counted.is_a?(Hash) ? counted.size : counted
    @total_count = counted.to_i
    @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
    @page = @total_pages if @page > @total_pages && @total_pages.positive?
    scope.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def like_query
    "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
  end
end
