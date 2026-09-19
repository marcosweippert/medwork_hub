class CreateUserAccount
  Result = Struct.new(:ok, :user, keyword_init: true) do
    def ok?
      ok
    end
  end

  def self.call(**attrs)
    new(**attrs).call
  end

  def self.temporary_password
    "#{SecureRandom.alphanumeric(5)}-#{SecureRandom.alphanumeric(4)}"
  end

  def initialize(name:, email:, role:, professional: {})
    @name = name
    @email = email
    @role = role.to_s.presence || "staff"
    @professional = (professional || {}).to_h.with_indifferent_access
  end

  def call
    password = self.class.temporary_password
    user = User.new(
      name: @name,
      email: @email,
      role: @role,
      password: password,
      password_confirmation: password,
      must_change_password: true
    )
    user.build_professional(professional_attrs) if user.role == "professional"

    if user.save
      ClinicMailer.welcome(user, password).deliver_now
      Result.new(ok: true, user: user)
    else
      Result.new(ok: false, user: user)
    end
  end

  private

  def professional_attrs
    {
      specialty: @professional[:specialty],
      license_number: @professional[:license_number],
      phone: @professional[:phone],
      bio: @professional[:bio],
      practice_areas: Array(@professional[:practice_areas]).map(&:presence).compact
    }
  end
end
