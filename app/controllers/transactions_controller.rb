class TransactionsController < ApplicationController
  before_action :require_clinic_staff

  def index
    redirect_to invoices_path(request.query_parameters.slice(:status, :q, :page))
  end
end
