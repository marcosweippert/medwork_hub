require "test_helper"

class PatientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @staff = User.create!(name: "Staff", email: "pat-staff-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    @pro_user = User.create!(name: "Dra. Ana", email: "pat-ana-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    @professional = Professional.create!(user: @pro_user, specialty: "Psychology", practice_areas: %w[psicologia_psiquiatria])
    @other_user = User.create!(name: "Dr. Other", email: "pat-other-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    @other = Professional.create!(user: @other_user, specialty: "Dentistry", practice_areas: %w[odontologia])
    @own = Patient.create!(professional: @professional, name: "Clara Luz", contact: "clara@example.com", history: "Acompanhamento")
    @foreign = Patient.create!(professional: @other, name: "Pedro Oculto", contact: "pedro@example.com")
  end

  test "professional sees only own patients and can export them" do
    sign_in @pro_user
    get patients_path
    assert_response :success
    assert_match "Clara Luz", response.body
    assert_no_match "Pedro Oculto", response.body

    get patient_path(@foreign)
    assert_response :not_found

    get export_patient_path(@own)
    assert_response :success
    assert_equal "application/json", response.media_type
    payload = JSON.parse(response.body)
    assert_equal "Clara Luz", payload.dig("patient", "name")
    assert_equal "Acompanhamento", payload.dig("patient", "history")
  end

  test "professional cannot reassign a patient" do
    sign_in @pro_user
    patch patient_path(@own), params: { patient: { name: "Clara Luz", professional_id: @other.id, contact: "nova@example.com" } }
    assert_redirected_to patient_path(@own)
    assert_equal @professional.id, @own.reload.professional_id
    assert_equal "nova@example.com", @own.contact
  end

  test "staff lists every patient" do
    sign_in @staff
    get patients_path
    assert_response :success
    assert_match "Clara Luz", response.body
    assert_match "Pedro Oculto", response.body
  end
end
