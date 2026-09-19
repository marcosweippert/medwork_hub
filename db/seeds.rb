# Frozen clinic history: 02/01/2024 – 31/08/2026
PERIOD_START = Date.new(2024, 1, 2)
PERIOD_END = Date.new(2026, 8, 31)
PASSWORD_DIGEST = Devise::Encryptor.digest(User, "password")
NOW = Time.current
SMTP_KEYS = %w[
  smtp_address smtp_port smtp_domain smtp_username smtp_password smtp_authentication
  smtp_enable_starttls mailer_from mailer_host mailer_port mailer_protocol
  welcome_email_subject welcome_email_html pix_key pix_name pix_city whatsapp_phone
].freeze

FIRST_NAMES = %w[
  Ana João Maria Pedro Carla Bruno Fernanda Rafael Lúcia Beatriz Thiago Camila
  Lucas Helena Paulo Juliana André Sofia Miguel Lara Ricardo Eduardo Patrícia
  Fábio Isabela Gustavo Amanda Henrique Nina Diego Letícia Marcelo Vitória
  Roberto Aline Felipe Bianca Alexandre Renata Gustavo Priscila Caio Larissa
  Daniel Vanessa Otávio Bruna Samuel Carolina Igor Natália Renan Elisa
].freeze

LAST_NAMES = %w[
  Silva Santos Oliveira Souza Pereira Lima Costa Rodrigues Almeida Nunes
  Ferreira Alves Barbosa Rocha Dias Castro Gomes Ribeiro Martins Carvalho
  Araújo Fernandes Azevedo Cardoso Teixeira Duarte Vieira Lopes Freitas
  Mendes Pires Barbosa Correia Moreira Andrade Cunha Monteiro Reis Campos
].freeze

SPECIALTIES = {
  "medicina" => ["Cardiologist", "Dermatologist", "Pediatrician", "Orthopedist", "General practitioner", "Endocrinologist", "Neurologist", "Gynecologist"],
  "odontologia" => ["Dentist", "Orthodontist", "Endodontist", "Periodontist"],
  "psicologia_psiquiatria" => ["Psychologist", "Psychiatrist", "Child psychologist", "CBT specialist"],
  "fisioterapia" => ["Physiotherapist", "Sports rehab", "Orthopedic physio"],
  "nutricao" => ["Nutritionist", "Sports nutritionist", "Clinical nutritionist"],
  "fonoaudiologia" => ["Speech therapist", "Child language therapist"]
}.freeze

AREA_COUNTS = {
  "medicina" => 110,
  "odontologia" => 45,
  "psicologia_psiquiatria" => 70,
  "fisioterapia" => 35,
  "nutricao" => 22,
  "fonoaudiologia" => 18
}.freeze

HISTORIES = [
  "Follow-up after first consult", "Anxiety treatment", "Sleep hygiene", "Orthodontic treatment",
  "Knee rehab", "Hypertension follow-up", "Weight management", "Acne treatment", "Speech delay",
  "Shoulder injury", "Well-child visits", "Depression follow-up", "Family therapy", "Root canal",
  "Post-op rehab", "Arrhythmia", "Sports nutrition", "Psoriasis", "Fluency", "ACL recovery"
].freeze

NOTE_BODIES = [
  "Session completed. Continue current plan.",
  "Patient reported improvement. Review in two weeks.",
  "Adjusted exercises and next booking confirmed.",
  "No adverse events. Maintain medication.",
  "Discussed home care and return if symptoms worsen."
].freeze

def stamp(time)
  time.respond_to?(:in_time_zone) ? time.in_time_zone : time
end

def full_name(index)
  "#{FIRST_NAMES[index % FIRST_NAMES.size]} #{LAST_NAMES[(index / FIRST_NAMES.size) % LAST_NAMES.size]} #{LAST_NAMES[(index * 7) % LAST_NAMES.size]}"
end

def insert_rows(model, rows, label)
  return if rows.blank?

  rows.each_slice(1_000).with_index do |slice, index|
    model.insert_all(slice)
    puts "  #{label}: #{[ (index + 1) * 1_000, rows.size ].min}/#{rows.size}"
  end
end

def outcome_for(date, salt)
  roll = (date.yday + salt) % 20
  return :cancelled if roll.zero?
  return :refunded if roll == 1
  return :overdue if roll == 2
  return :open if date > Date.new(2026, 8, 1) && roll >= 16

  :paid
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
setting = Setting.create!(
  {
    clinic_name: "MedWork Hub",
    clinic_email: "marcos.weippert@gmail.com",
    clinic_phone: "1130001000",
    currency: "BRL",
    slot_minutes: 30,
    pix_key: smtp["pix_key"].presence || "medwork@pix.example",
    pix_name: smtp["pix_name"].presence || "MedWork Hub",
    pix_city: smtp["pix_city"].presence || "Sao Paulo"
  }.merge(smtp.compact)
)
MailerConfig.reload!
puts "Clinic settings ready. Mailer: #{MailerConfig.delivery_method} via #{MailerConfig.address.presence || 'file'}."

rooms_data = [
  ["Sala 01", 2, "Desk, chairs, computer", 280, 4200, 35, 8, 18, %w[medicina]],
  ["Sala 02", 2, "Exam table, monitor", 300, 4500, 38, 8, 18, %w[medicina]],
  ["Sala 03", 2, "Pediatric kit", 260, 3900, 32, 8, 18, %w[medicina psicologia_psiquiatria]],
  ["Sala 04", 1, "Dental chair, sterilizer", 450, 6800, 55, 8, 18, %w[odontologia]],
  ["Sala 05", 1, "Dental imaging", 480, 7200, 58, 8, 18, %w[odontologia]],
  ["Sala 06", 2, "Couch, chairs, whiteboard", 220, 3300, 28, 8, 20, %w[psicologia_psiquiatria]],
  ["Sala 07", 2, "Quiet therapy room", 230, 3400, 30, 8, 20, %w[psicologia_psiquiatria]],
  ["Sala 08", 8, "Mats, sound system", 360, 5400, 45, 7, 21, %w[fisioterapia]],
  ["Sala 09", 2, "Nutrition consult", 210, 3100, 26, 8, 18, %w[nutricao]],
  ["Sala 10", 2, "Speech therapy tools", 200, 3000, 25, 8, 19, %w[fonoaudiologia]]
]
now = NOW
Room.insert_all(
  rooms_data.map do |name, capacity, equipment, daily, monthly, hourly, opens, closes, types|
    {
      name: name, capacity: capacity, equipment: equipment,
      daily_rate: daily, monthly_rate: monthly, hourly_rate: hourly,
      opens_at: opens, closes_at: closes, room_types: types, closed_weekdays: [],
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
RoomBlock.create!(
  room: rooms.find { |room| room.name == "Sala 08" },
  starts_at: Date.new(2026, 3, 2).in_time_zone.change(hour: 8),
  ends_at: Date.new(2026, 3, 6).in_time_zone.change(hour: 18),
  reason: "Floor maintenance",
  weekdays: []
)

user_rows = []
professional_attrs = []
index = 0
AREA_COUNTS.each do |area, count|
  count.times do
    index += 1
    name = index <= 10 ? ["Dr. Ana Silva", "Dr. João Pereira", "Dra. Carla Mendes", "Dr. Bruno Costa", "Dra. Fernanda Alves", "Dr. Rafael Souza", "Dra. Lúcia Rocha", "Dr. Pedro Nunes", "Dra. Beatriz Lima", "Dr. Thiago Martins"][index - 1] : full_name(index)
    email = index <= 10 ? %w[ana joao carla bruno fernanda rafael lucia pedro beatriz thiago][index - 1] + "@medworkhub.com" : "pro#{index.to_s.rjust(3, '0')}@medworkhub.com"
    specialty = SPECIALTIES[area][index % SPECIALTIES[area].size]
    created = PERIOD_START.in_time_zone + ((index % 400).days)
    user_rows << {
      email: email,
      encrypted_password: PASSWORD_DIGEST,
      name: name,
      role: "professional",
      must_change_password: false,
      created_at: created,
      updated_at: created
    }
    professional_attrs << {
      email: email,
      specialty: specialty,
      license_number: "#{area[0, 3].upcase}#{index.to_s.rjust(5, '0')}",
      bio: "#{specialty} at MedWork Hub.",
      phone: "11#{9_0000_0000 + index}",
      practice_areas: [area],
      created_at: created,
      updated_at: created
    }
  end
end

user_rows << {
  email: "staff@medworkhub.com",
  encrypted_password: PASSWORD_DIGEST,
  name: "Staff User",
  role: "staff",
  must_change_password: false,
  created_at: PERIOD_START.in_time_zone,
  updated_at: PERIOD_START.in_time_zone
}

insert_rows(User, user_rows, "Users")
users_by_email = User.pluck(:email, :id).to_h

Professional.insert_all(
  professional_attrs.map do |attrs|
    email = attrs.delete(:email)
    attrs.merge(user_id: users_by_email.fetch(email))
  end
)
professionals = Professional.includes(:user).order(:id).to_a
pros_by_area = SPECIALTIES.keys.index_with { |area| professionals.select { |pro| pro.practice_areas.include?(area) } }
puts "Professionals: #{professionals.size}"

patient_rows = 500.times.map do |i|
  pro = professionals[i % professionals.size]
  created = PERIOD_START.in_time_zone + (i % 600).days
  {
    professional_id: pro.id,
    name: full_name(i + 50),
    contact: "11#{9_1000_0000 + i}",
    history: HISTORIES[i % HISTORIES.size],
    created_at: created,
    updated_at: created
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
  pool = room.room_types.flat_map { |type| pros_by_area[type] || [] }.uniq
  next if pool.empty?

  lunch_blocked = room.room_types.include?("odontologia")
  (PERIOD_START..PERIOD_END).each do |date|
    next if date.sunday?
    next if date.month == 12 && date.day == 25
    next if room.name == "Sala 08" && date.between?(Date.new(2026, 3, 2), Date.new(2026, 3, 6))

    open = date.saturday? ? [room.opens_at, 9].max : room.opens_at
    close = date.saturday? ? [room.closes_at, 13].min : room.closes_at
    next if close - open < 2
    next if (date.yday + room.id) % 5 == 0

    pattern = (date.yday + room.id) % 11
    if pattern == 0 && !date.saturday?
      pro = pool[(date.mday + room.id) % pool.size]
      seq += 1
      starts = date.in_time_zone.change(hour: open)
      ends = date.in_time_zone.change(hour: close)
      amount = room.daily_rate.to_d
      apply_reservation(invoice_rows, booking_rows, seq, pro, room, starts, ends, amount, "daily", date, patients_by_pro)
      next
    end

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

rooms.each do |room|
  pool = room.room_types.flat_map { |type| pros_by_area[type] || [] }.uniq
  next if pool.empty?

  month = PERIOD_START.beginning_of_month
  while month <= PERIOD_END
    pro = pool[month.month % pool.size]
    seq += 1
    starts = [month, PERIOD_START].max.in_time_zone.change(hour: room.opens_at)
    last_day = [month.end_of_month, PERIOD_END].min
    ends = last_day.in_time_zone.change(hour: room.closes_at)
    apply_reservation(invoice_rows, booking_rows, seq, pro, room, starts, ends, room.monthly_rate.to_d, "monthly", month, patients_by_pro)
    month = month.next_month
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

note_source = Booking.where.not(patient_id: nil).where(status: %w[completed confirmed]).limit(800).pluck(:id, :patient_id, :start_time)
note_rows = note_source.first(400).map.with_index do |(booking_id, patient_id, start_time), i|
  {
    booking_id: booking_id,
    patient_id: patient_id,
    body: NOTE_BODIES[i % NOTE_BODIES.size],
    created_at: start_time,
    updated_at: start_time
  }
end
insert_rows(AppointmentNote, note_rows, "Notes")

hold_slots = Booking.where(status: %w[pending confirmed completed]).order(:id).limit(120).pluck(:room_id, :professional_id, :start_time, :end_time)
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

audit_rows = 250.times.map do |i|
  {
    user_id: users_by_email["staff@medworkhub.com"],
    action: %w[booking.created invoice.paid invoice.cancelled invoice.refunded waitlist.created][i % 5],
    auditable_type: %w[Booking Invoice Invoice Invoice WaitlistEntry][i % 5],
    auditable_id: i + 1,
    details: { seed: true }.to_json,
    created_at: PERIOD_START.in_time_zone + (i * 3).days,
    updated_at: PERIOD_START.in_time_zone + (i * 3).days
  }
end
insert_rows(AuditEvent, audit_rows, "Audit")

puts "Creating admin marcos.weippert@gmail.com and sending welcome email..."
password = CreateUserAccount.temporary_password
admin = User.new(
  name: "Marcos Weippert",
  email: "marcos.weippert@gmail.com",
  role: "admin",
  password: password,
  password_confirmation: password,
  must_change_password: true
)
if admin.save
  MailerConfig.reload!
  begin
    ClinicMailer.welcome(admin, password).deliver_now
    puts "Welcome email sent to marcos.weippert@gmail.com"
    puts "Temporary password: #{password}"
  rescue StandardError => e
    puts "Admin created, but welcome email failed: #{e.class}: #{e.message}"
    puts "Temporary password: #{password}"
  end
else
  puts "Could not create admin: #{admin.errors.full_messages.to_sentence}"
end

paid = Invoice.where(status: "paid").count
cancelled = Invoice.where(status: "cancelled").count
refunded = Invoice.where(status: "refunded").count
overdue = Invoice.where(status: "overdue").count
open = Invoice.where(status: "open").count
refund_total = Invoice.sum(:refunded_amount)

puts "Seed complete."
puts "Period: #{PERIOD_START} – #{PERIOD_END}"
puts "Professionals: #{Professional.count} · Patients: #{Patient.count} · Rooms: #{Room.count}"
puts "Bookings: #{Booking.count} · Waitlist: #{WaitlistEntry.count} · Notes: #{AppointmentNote.count}"
puts "Invoices: #{Invoice.count} (paid #{paid}, open #{open}, overdue #{overdue}, cancelled #{cancelled}, refunded #{refunded})"
puts "Refunded amount: #{refund_total}"
puts "Staff login: staff@medworkhub.com / password"
puts "Admin: marcos.weippert@gmail.com (password in the welcome email)"
ActiveRecord::Base.logger = previous_logger
