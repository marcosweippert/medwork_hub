class InvoicesController < ApplicationController
  before_action :require_clinic_staff, except: %i[index show]
  before_action :set_invoice, only: %i[show edit update destroy pay refund cancel cancel_slots]
  layout :invoice_layout

  def index
    @professionals = professional_user? ? Array(current_professional) : Professional.includes(:user)
    @invoices = paginate(
      filtered_invoices.includes(:room, professional: :user, bookings: :room),
      per: 20
    )
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data invoice_pdf,
                  filename: "invoice-#{@invoice.id}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end

  def new
    @invoice = Invoice.new(due_date: Date.current)
  end

  def create
    @invoice = Invoice.new(invoice_params)
    if @invoice.save
      redirect_to path_with_return(invoice_path(@invoice)), notice: "Invoice created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @invoice.update(invoice_params)
      redirect_to path_with_return(invoice_path(@invoice)), notice: "Invoice updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice.destroy
    redirect_back_to invoices_url, notice: "Invoice deleted."
  end

  def pay
    @invoice.mark_paid!
    redirect_back_to @invoice, notice: "Invoice marked as paid."
  end

  def refund
    result = RefundInvoice.new(invoice: @invoice, reason: params[:reason], amount: params[:amount]).call
    if result.success?
      redirect_back_to @invoice, notice: "Refund recorded. Future slots on this invoice were released."
    else
      redirect_back_to @invoice, alert: result.error
    end
  end

  def cancel
    result = CancelInvoice.new(invoice: @invoice, reason: params[:reason]).call
    if result.success?
      message = if result.refund.to_d.positive?
                  "Invoice cancelled. Refund #{helpers.number_to_currency(result.refund)}" \
                    "#{result.fee.to_d.positive? ? " · kept #{helpers.number_to_currency(result.fee)}" : ""}."
                else
                  "Invoice cancelled and slots released."
                end
      redirect_back_to @invoice, notice: message
    else
      redirect_back_to @invoice, alert: result.error
    end
  end

  def cancel_slots
    result = CancelBookingSlots.new(invoice: @invoice, slot_starts: params[:slot_starts], reason: params[:reason]).call
    if result.success?
      message = if result.refund.to_d.positive?
                  "Selected slots cancelled. Refund #{helpers.number_to_currency(result.refund)}" \
                    "#{result.fee.to_d.positive? ? " · kept #{helpers.number_to_currency(result.fee)}" : ""}."
                else
                  "Selected slots cancelled and released."
                end
      redirect_back_to @invoice, notice: message
    else
      redirect_back_to @invoice, alert: result.error
    end
  end

  def bulk
    invoices = bulk_invoices_scope
    if invoices.none?
      redirect_back_to invoices_path, alert: "Select at least one invoice."
      return
    end

    result = BulkInvoiceAction.new(invoices: invoices, action: params[:bulk_action], reason: params[:reason]).call
    redirect_back_to invoices_path, **bulk_flash(result)
  end

  private

  def set_invoice
    @invoice = scope_to_current_professional(Invoice.includes(:room, professional: :user, bookings: :room)).find(params[:id])
  end

  def filtered_invoices
    invoices = Invoice.order(created_at: :desc)
    invoices = scope_to_current_professional(invoices)
    invoices = invoices.where(status: params[:status]) if params[:status].present?
    invoices = invoices.where(professional_id: params[:professional_id]) if params[:professional_id].present?
    due_from = filter_date(:from)
    due_to = filter_date(:to)
    invoices = invoices.where("due_date >= ?", due_from) if due_from
    invoices = invoices.where("due_date <= ?", due_to) if due_to
    if params[:q].present?
      invoices = invoices.left_joins(:room, professional: :user).where(
        "users.name ILIKE :q OR rooms.name ILIKE :q OR invoices.notes ILIKE :q",
        q: like_query
      ).distinct
    end
    invoices
  end

  def bulk_invoices_scope
    if params[:select_matching].to_s == "1"
      filtered_invoices
    else
      scope_to_current_professional(Invoice.where(id: Array(params[:invoice_ids])))
    end
  end

  def filter_date(key)
    raw = params[key].to_s.strip
    return if raw.blank?

    Date.parse(raw)
  rescue Date::Error, ArgumentError
    nil
  end

  def invoice_params
    params.require(:invoice).permit(:professional_id, :room_id, :amount, :status, :due_date, :notes)
  end

  def invoice_pdf
    InvoicePdf.render(@invoice)
  end

  def invoice_layout
    action_name == "show" && params[:print].present? ? "print" : "application"
  end

  def bulk_flash(result)
    parts = []
    parts << "#{result.paid} paid" if result.paid.positive?
    parts << "#{result.cancelled} cancelled" if result.cancelled.positive?
    parts << "#{result.refunded} refunded" if result.refunded.positive?
    parts << "#{result.skipped} skipped" if result.skipped.positive?
    message = parts.any? ? "Bulk update: #{parts.join(", ")}." : "No invoices were updated."
    message = [message, *result.errors].join(" ")
    succeeded = result.paid.positive? || result.cancelled.positive? || result.refunded.positive?
    succeeded ? { notice: message } : { alert: message }
  end
end
