class BulkInvoiceAction
  Result = Struct.new(:paid, :cancelled, :refunded, :skipped, :errors, keyword_init: true)

  def initialize(invoices:, action:, reason: nil)
    @invoices = invoices
    @action = action.to_s
    @reason = reason
  end

  def call
    counts = { paid: 0, cancelled: 0, refunded: 0, skipped: 0 }
    errors = []

    @invoices.find_each do |invoice|
      case @action
      when "pay"
        next counts[:skipped] += 1 unless invoice.payable?
        invoice.mark_paid!
        counts[:paid] += 1
      when "cancel"
        result = CancelInvoice.new(invoice: invoice, reason: @reason).call
        if result.success?
          if invoice.reload.status == "refunded"
            counts[:refunded] += 1
          else
            counts[:cancelled] += 1
          end
        else
          counts[:skipped] += 1
          errors << "Invoice ##{invoice.id}: #{result.error}"
        end
      when "refund"
        unless invoice.refundable?
          counts[:skipped] += 1
          next
        end
        result = RefundInvoice.new(invoice: invoice, reason: @reason).call
        if result.success?
          counts[:refunded] += 1
        else
          errors << "Invoice ##{invoice.id}: #{result.error}"
        end
      else
        errors << "Unknown action."
        break
      end
    rescue ActiveRecord::RecordInvalid => e
      errors << "Invoice ##{invoice.id}: #{e.record.errors.full_messages.to_sentence}"
    end

    Result.new(**counts, errors: errors)
  end
end
