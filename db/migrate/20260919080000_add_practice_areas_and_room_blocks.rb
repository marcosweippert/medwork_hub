class AddPracticeAreasAndRoomBlocks < ActiveRecord::Migration[7.1]
  def up
    add_column :rooms, :room_types, :string, array: true, default: []
    add_column :rooms, :closed_weekdays, :integer, array: true, default: []
    add_column :professionals, :practice_areas, :string, array: true, default: []
    add_column :room_blocks, :weekdays, :integer, array: true, default: []

    Room.reset_column_information
    Professional.reset_column_information

    Room.find_each do |room|
      types = PracticeArea.infer_room_types(room.name)
      room.update_columns(room_types: types) if types.any?
    end

    Professional.find_each do |professional|
      areas = PracticeArea.infer_from_specialty(professional.specialty)
      professional.update_columns(practice_areas: areas)
    end
  end

  def down
    remove_column :room_blocks, :weekdays
    remove_column :professionals, :practice_areas
    remove_column :rooms, :closed_weekdays
    remove_column :rooms, :room_types
  end
end
