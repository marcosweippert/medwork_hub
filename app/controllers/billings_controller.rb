class BillingsController < ApplicationController
  before_action :require_clinic_staff

  def show
    redirect_to invoices_path
  end
end
