class PracticeArea
  ROOM_TYPES = {
    "medicina" => "Medicina",
    "odontologia" => "Odontologia",
    "psicologia_psiquiatria" => "Psicologia / Psiquiatria",
    "fisioterapia" => "Fisioterapia",
    "nutricao" => "Nutrição",
    "fonoaudiologia" => "Fonoaudiologia"
  }.freeze

  AREAS = {
    "medicina" => { label: "Medicina", room_types: %w[medicina psicologia_psiquiatria] },
    "odontologia" => { label: "Odontologia", room_types: %w[odontologia] },
    "psicologia_psiquiatria" => { label: "Psicologia / Psiquiatria", room_types: %w[psicologia_psiquiatria] },
    "fisioterapia" => { label: "Fisioterapia", room_types: %w[fisioterapia] },
    "nutricao" => { label: "Nutrição", room_types: %w[nutricao] },
    "fonoaudiologia" => { label: "Fonoaudiologia", room_types: %w[fonoaudiologia] }
  }.freeze

  def self.keys
    AREAS.keys
  end

  def self.room_type_keys
    ROOM_TYPES.keys
  end

  def self.label(key)
    AREAS.dig(key.to_s, :label) || ROOM_TYPES[key.to_s] || key.to_s.humanize
  end

  def self.room_type_label(key)
    ROOM_TYPES[key.to_s] || key.to_s.humanize
  end

  def self.room_types_for(area_key)
    AREAS.dig(area_key.to_s, :room_types) || []
  end

  def self.labels_for(keys)
    Array(keys).map { |key| label(key) }.compact
  end

  def self.room_type_labels_for(keys)
    Array(keys).map { |key| room_type_label(key) }.compact
  end

  def self.infer_from_specialty(specialty)
    text = specialty.to_s.downcase
    return %w[odontologia] if text.match?(/dent|odonto/)
    return %w[psicologia_psiquiatria] if text.match?(/psychol|psychiat|psico|psiquiat/)
    return %w[fisioterapia] if text.match?(/physio|fisio/)
    return %w[nutricao] if text.match?(/nutri/)
    return %w[fonoaudiologia] if text.match?(/speech|fono/)
    return %w[medicina] if text.match?(/cardio|derma|orthop|ortop|pediatr|medic|clinic/)

    %w[medicina]
  end

  def self.infer_room_types(name)
    text = name.to_s.downcase
    types = []
    types << "odontologia" if text.match?(/odonto|dental|dent/)
    types << "psicologia_psiquiatria" if text.match?(/psico|psiquiat|therapy|terapia/)
    types << "fisioterapia" if text.match?(/fisio|rehab|studio|group/)
    types << "nutricao" if text.match?(/nutri/)
    types << "fonoaudiologia" if text.match?(/fono|speech/)
    types << "medicina" if text.match?(/medic|pediatr|cardio|derma|ortop|consult/)
    types.uniq
  end
end
