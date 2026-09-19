# Compact demo data for local testing. Does not send email.
PERIOD_START = Date.new(2024, 1, 2)
PERIOD_END = Date.new(2026, 10, 30)
ADMIN_EMAIL = "admin@medworkhub.com"
ADMIN_PASSWORD = "MedWorkHub@123"
ADMIN_DIGEST = Devise::Encryptor.digest(User, ADMIN_PASSWORD)
PASSWORD_DIGEST = Devise::Encryptor.digest(User, "password")
NOW = Time.current
SMTP_KEYS = %w[
  smtp_address smtp_port smtp_domain smtp_username smtp_password smtp_authentication
  smtp_enable_starttls mailer_from mailer_host mailer_port mailer_protocol
  welcome_email_subject welcome_email_html pix_key pix_name pix_city whatsapp_phone
].freeze

SPECIALTIES = {
  "medicina" => ["Cardiologist", "Pediatrician"],
  "odontologia" => ["Dentist", "Orthodontist"],
  "psicologia_psiquiatria" => ["Psychologist", "Psychiatrist"],
  "fisioterapia" => ["Physiotherapist", "Sports rehab"],
  "nutricao" => ["Nutritionist", "Clinical nutritionist"],
  "fonoaudiologia" => ["Speech therapist", "Child language therapist"]
}.freeze

DEMO_PROS = [
  ["Dr. Ana Silva", "ana@medworkhub.com", "medicina"],
  ["Dr. João Pereira", "joao@medworkhub.com", "medicina"],
  ["Dra. Carla Mendes", "carla@medworkhub.com", "odontologia"],
  ["Dr. Bruno Costa", "bruno@medworkhub.com", "odontologia"],
  ["Dra. Fernanda Alves", "fernanda@medworkhub.com", "psicologia_psiquiatria"],
  ["Dr. Rafael Souza", "rafael@medworkhub.com", "psicologia_psiquiatria"],
  ["Dra. Lúcia Rocha", "lucia@medworkhub.com", "fisioterapia"],
  ["Dr. Pedro Nunes", "pedro@medworkhub.com", "fisioterapia"],
  ["Dra. Beatriz Lima", "beatriz@medworkhub.com", "nutricao"],
  ["Dr. Thiago Martins", "thiago@medworkhub.com", "nutricao"],
  ["Dra. Helena Dias", "helena@medworkhub.com", "fonoaudiologia"],
  ["Dr. Lucas Ferreira", "lucas@medworkhub.com", "fonoaudiologia"]
].freeze

HISTORIES = [
  "Follow-up after first consult", "Anxiety treatment", "Orthodontic treatment",
  "Knee rehab", "Weight management", "Speech delay"
].freeze

NOTE_BODIES = [
  "Session completed. Continue current plan.",
  "Patient reported improvement. Review in two weeks.",
  "Adjusted exercises and next booking confirmed."
].freeze

def insert_rows(model, rows, label)
  return if rows.blank?

  rows.each_slice(1_000).with_index do |slice, index|
    model.insert_all(slice)
    puts "  #{label}: #{[(index + 1) * 1_000, rows.size].min}/#{rows.size}"
  end
end

def seed_date?(date)
  return false if date.sunday?
  return false if date.month == 12 && date.day == 25
  return true if date.between?(Date.current - 21.days, Date.current + 21.days)

  date.day == 15 && date.wday.between?(1, 5)
end

def outcome_for(date, salt)
  roll = (salt * 31 + date.yday * 17 + date.year) % 100
  outcome = if roll < 6
              :cancelled
            elsif roll < 11
              :refunded
            elsif roll < 16
              :overdue
            elsif roll < 20
              :open
            else
              :paid
            end
  return :open if outcome == :overdue && date >= Date.current

  outcome
end

def apply_reservation(invoice_rows, booking_rows, seq, pro, room, starts, ends, amount, billing_type, date, patients_by_pro)
  outcome = outcome_for(date, seq + room.id)
  created = starts - 2.days
  created = PERIOD_START.in_time_zone if created < PERIOD_START.in_time_zone
  paid_at = nil
  refunded_at = nil
  cancelled_at = nil
  refunded_amount = 0
  cancellation_fee = 0
  invoice_status = "paid"
  booking_status = "completed"
  booking_cancelled_at = nil
  reason = nil

  case outcome
  when :paid
    paid_at = created + 6.hours
    invoice_status = "paid"
    booking_status = ends < NOW ? "completed" : "confirmed"
  when :open
    invoice_status = "open"
    booking_status = "pending"
  when :overdue
    invoice_status = "overdue"
    booking_status = "pending"
  when :cancelled
    invoice_status = "cancelled"
    cancelled_at = created + 1.day
    booking_status = "cancelled"
    booking_cancelled_at = cancelled_at
    reason = "Reservation cancelled"
  when :refunded
    invoice_status = "refunded"
    paid_at = created + 4.hours
    refunded_at = paid_at + 8.days
    cancellation_fee = (amount.to_d * 0.5).round(2)
    refunded_amount = (amount.to_d - cancellation_fee).round(2)
    booking_status = "cancelled"
    booking_cancelled_at = refunded_at
    reason = "Cancelled after payment · policy refund"
  end

  due = if invoice_status.in?(%w[paid refunded])
          date
        elsif invoice_status == "overdue"
          date - 2
        else
          date + 7
        end

  patient = (patients_by_pro[pro.id] || []).sample
  invoice_rows << {
    professional_id: pro.id,
    room_id: room.id,
    amount: amount,
    status: invoice_status,
    due_date: due,
    notes: "#{billing_type.titleize} · #{room.name} · #{starts.strftime('%d/%m/%Y %H:%M')}",
    paid_at: paid_at,
    refunded_at: refunded_at,
    refunded_amount: refunded_amount,
    refund_reason: outcome == :refunded ? reason : nil,
    cancelled_at: cancelled_at,
    cancellation_reason: outcome == :cancelled ? reason : nil,
    cancellation_fee: cancellation_fee,
    pix_txid: "SEED#{seq.to_s(36)}#{room.id}",
    reminder_sent_at: created,
    created_at: created,
    updated_at: (refunded_at || cancelled_at || paid_at || created)
  }
  booking_rows << {
    professional_id: pro.id,
    room_id: room.id,
    start_time: starts,
    end_time: ends,
    status: booking_status,
    amount: amount,
    billing_type: billing_type,
    cancelled_at: booking_cancelled_at,
    cancellation_reason: reason,
    patient_id: patient&.id,
    reminder_sent_at: created,
    created_at: created,
    updated_at: (booking_cancelled_at || created)
  }
end

puts "Cleaning transactional data (SMTP settings are kept)..."
previous_logger = ActiveRecord::Base.logger
ActiveRecord::Base.logger = Logger.new($stdout, level: Logger::WARN)
AppointmentNote.delete_all
WaitlistEntry.delete_all
Booking.delete_all
Invoice.delete_all
Patient.delete_all
RoomBlock.delete_all
Professional.delete_all
Room.delete_all
AuditEvent.delete_all
OutboundEmail.delete_all
Dashboard.delete_all
User.delete_all

smtp = Setting.order(:id).first&.attributes&.slice(*SMTP_KEYS) || {}
Setting.delete_all
Setting.create!(
  {
    clinic_name: "MedWork Hub",
    clinic_email: ADMIN_EMAIL,
    clinic_phone: "1130001000",
    currency: "BRL",
    slot_minutes: 30,
    pix_key: smtp["pix_key"].presence || "medwork@pix.example",
    pix_name: smtp["pix_name"].presence || "MedWork Hub",
    pix_city: smtp["pix_city"].presence || "Sao Paulo"
  }.merge(smtp.compact)
)
puts "Clinic settings ready."

rooms_data = [
  ["Sala 01", 2, "Consultório clínico", 280, 4200, 35, 8, 18, %w[medicina]],
  ["Sala 02", 2, "Consultório compartilhado", 270, 4000, 34, 8, 19, %w[medicina psicologia_psiquiatria]],
  ["Sala 03", 1, "Odontologia", 450, 6800, 55, 8, 18, %w[odontologia]],
  ["Sala 04", 2, "Terapia", 220, 3300, 28, 8, 20, %w[psicologia_psiquiatria]],
  ["Sala 05", 8, "Estúdio de fisioterapia", 360, 5400, 45, 7, 21, %w[fisioterapia]],
  ["Sala 06", 2, "Nutrição clínica", 210, 3100, 26, 8, 18, %w[nutricao]],
  ["Sala 07", 2, "Fonoaudiologia", 200, 3000, 25, 8, 19, %w[fonoaudiologia]],
  ["Sala 08", 2, "Consultório misto", 250, 3700, 33, 8, 18, %w[medicina nutricao]]
]
now = NOW
Room.insert_all(
  rooms_data.map do |name, capacity, equipment, daily, monthly, hourly, opens, closes, types|
    {
      name: name, capacity: capacity, equipment: equipment,
      daily_rate: daily, monthly_rate: monthly, hourly_rate: hourly,
      opens_at: opens, closes_at: closes, room_types: types, closed_weekdays: [0],
      created_at: now, updated_at: now
    }
  end
)
rooms = Room.order(:id).to_a
puts "Rooms: #{rooms.size}"

RoomBlock.create!(
  room: rooms.find { |room| room.room_types.include?("odontologia") },
  starts_at: PERIOD_START.in_time_zone.change(hour: 12),
  ends_at: PERIOD_START.in_time_zone.change(hour: 13),
  reason: "Sterilization / lunch",
  weekdays: [1, 2, 3, 4, 5]
)
RoomBlock.create!(
  room: nil,
  starts_at: Date.new(2025, 12, 25).in_time_zone.change(hour: 0),
  ends_at: Date.new(2025, 12, 25).in_time_zone.change(hour: 23, min: 59),
  reason: "Christmas",
  weekdays: []
)

created_at = PERIOD_START.in_time_zone
user_rows = [
  {
    email: ADMIN_EMAIL,
    encrypted_password: ADMIN_DIGEST,
    name: "Admin",
    role: "admin",
    must_change_password: false,
    created_at: created_at,
    updated_at: created_at
  },
  {
    email: "staff@medworkhub.com",
    encrypted_password: PASSWORD_DIGEST,
    name: "Staff User",
    role: "staff",
    must_change_password: false,
    created_at: created_at,
    updated_at: created_at
  }
]

professional_attrs = DEMO_PROS.map.with_index do |(name, email, area), index|
  user_rows << {
    email: email,
    encrypted_password: PASSWORD_DIGEST,
    name: name,
    role: "professional",
    must_change_password: false,
    created_at: created_at,
    updated_at: created_at
  }
  {
    email: email,
    specialty: SPECIALTIES[area][index % SPECIALTIES[area].size],
    license_number: "#{area[0, 3].upcase}#{(index + 1).to_s.rjust(5, '0')}",
    bio: "#{SPECIALTIES[area][index % SPECIALTIES[area].size]} at MedWork Hub.",
    phone: "11#{9_0000_0000 + index + 1}",
    practice_areas: [area],
    created_at: created_at,
    updated_at: created_at
  }
end

insert_rows(User, user_rows, "Users")
users_by_email = User.pluck(:email, :id).to_h

Professional.insert_all(
  professional_attrs.map do |attrs|
    email = attrs.delete(:email)
    attrs.merge(user_id: users_by_email.fetch(email))
  end
)
professionals = Professional.includes(:user).order(:id).to_a
pros_by_type = Hash.new { |hash, key| hash[key] = [] }
professionals.each do |pro|
  pro.allowed_room_types.each { |type| pros_by_type[type] << pro }
end
puts "Professionals: #{professionals.size}"

patient_rows = 36.times.map do |i|
  pro = professionals[i % professionals.size]
  {
    professional_id: pro.id,
    name: ["Ana Costa", "Pedro Lima", "Maria Souza", "João Alves", "Carla Nunes", "Bruno Dias"][i % 6] + " #{i + 1}",
    contact: "11#{9_1000_0000 + i}",
    history: HISTORIES[i % HISTORIES.size],
    created_at: created_at,
    updated_at: created_at
  }
end
insert_rows(Patient, patient_rows, "Patients")
patients = Patient.order(:id).to_a
patients_by_pro = patients.group_by(&:professional_id)
puts "Patients: #{patients.size}"

invoice_rows = []
booking_rows = []
seq = 0

rooms.each do |room|
  pool = room.room_types.flat_map { |type| pros_by_type[type] }.uniq
  next if pool.empty?

  lunch_blocked = room.room_types.include?("odontologia")
  (PERIOD_START..PERIOD_END).each do |date|
    next unless seed_date?(date)

    open = date.saturday? ? [room.opens_at, 8].max : room.opens_at
    close = date.saturday? ? [room.closes_at, 13].min : room.closes_at
    next if close - open < 2

    hour = open
    slot_n = 0
    while hour + 1 <= close
      if lunch_blocked && hour == 12
        hour += 1
        next
      end
      skip = ((date.yday + hour + room.id) % 3).zero?
      if skip
        hour += 1
        next
      end
      duration = ((date.mday + hour) % 2).zero? ? 2 : 1
      duration = 1 if hour + duration > close
      pro = pool[(date.yday + slot_n + room.id) % pool.size]
      seq += 1
      starts = date.in_time_zone.change(hour: hour)
      ends = starts + duration.hours
      amount = (duration * room.hourly_rate.to_d).round(2)
      apply_reservation(invoice_rows, booking_rows, seq, pro, room, starts, ends, amount, "hourly", date, patients_by_pro)
      hour += duration
      slot_n += 1
    end
  end
end

puts "Inserting #{invoice_rows.size} invoices and bookings..."
invoice_rows.each_slice(1_000).with_index do |inv_slice, index|
  start = index * 1_000
  book_slice = booking_rows[start, inv_slice.size]
  ids = Invoice.insert_all(inv_slice, returning: %w[id]).rows.flatten
  book_slice.each_with_index { |row, offset| row[:invoice_id] = ids[offset] }
  Booking.insert_all(book_slice)
  puts "  Reservations: #{[start + inv_slice.size, invoice_rows.size].min}/#{invoice_rows.size}"
end
puts "Invoices: #{Invoice.count} · Bookings: #{Booking.count}"

note_source = Booking.where.not(patient_id: nil).where(status: %w[completed confirmed]).limit(40).pluck(:id, :patient_id, :start_time)
note_rows = note_source.first(20).map.with_index do |(booking_id, patient_id, start_time), i|
  {
    booking_id: booking_id,
    patient_id: patient_id,
    body: NOTE_BODIES[i % NOTE_BODIES.size],
    created_at: start_time,
    updated_at: start_time
  }
end
insert_rows(AppointmentNote, note_rows, "Notes")

hold_slots = Booking.where(status: %w[pending confirmed completed]).order(:id).limit(15).pluck(:room_id, :professional_id, :start_time, :end_time)
wait_rows = hold_slots.map.with_index do |(room_id, professional_id, starts, ends), i|
  status = %w[waiting waiting offered booked cancelled][i % 5]
  {
    room_id: room_id,
    professional_id: professional_id,
    starts_at: starts,
    ends_at: ends,
    status: status,
    notified_at: status == "offered" ? starts - 2.hours : nil,
    created_at: starts - 1.day,
    updated_at: starts - 1.day
  }
end
insert_rows(WaitlistEntry, wait_rows, "Waitlist")

audit_rows = 20.times.map do |i|
  {
    user_id: users_by_email[ADMIN_EMAIL],
    action: %w[booking.created invoice.paid invoice.cancelled invoice.refunded waitlist.created][i % 5],
    auditable_type: %w[Booking Invoice Invoice Invoice WaitlistEntry][i % 5],
    auditable_id: i + 1,
    details: { seed: true }.to_json,
    created_at: PERIOD_START.in_time_zone + (i * 3).days,
    updated_at: PERIOD_START.in_time_zone + (i * 3).days
  }
end
insert_rows(AuditEvent, audit_rows, "Audit")

paid = Invoice.where(status: "paid").count
cancelled = Invoice.where(status: "cancelled").count
refunded = Invoice.where(status: "refunded").count
overdue = Invoice.where(status: "overdue").count
open = Invoice.where(status: "open").count

puts "Seed complete. No welcome email was sent."
puts "Period samples: #{PERIOD_START} – #{PERIOD_END} (dense window around today + the 15th of each month)"
puts "Professionals: #{Professional.count} · Patients: #{Patient.count} · Rooms: #{Room.count}"
puts "Bookings: #{Booking.count} · Waitlist: #{WaitlistEntry.count} · Notes: #{AppointmentNote.count}"
puts "Invoices: #{Invoice.count} (paid #{paid}, open #{open}, overdue #{overdue}, cancelled #{cancelled}, refunded #{refunded})"
puts "Admin: #{ADMIN_EMAIL} / #{ADMIN_PASSWORD}"
puts "Staff: staff@medworkhub.com / password"
puts "Professionals: ana@medworkhub.com … lucas@medworkhub.com / password"
ActiveRecord::Base.logger = previous_logger
