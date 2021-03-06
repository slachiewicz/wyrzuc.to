module ImportData
  # This class provides methods that allow you to import information about wet and dry wastes
  class WetAndDryWastes < Base
    # rubocop:disable all
    def import
      if params['area'].present?
        Waste.wet_and_dry_wastes.where(area: params['area']).delete_all
      end

      sheets_names.each do |sheet_name|
        excel.sheet(sheet_name)
        (4..excel.last_row).each do |row|
          next if excel.cell(row, 1).nil? || excel.row(row)[4..21].compact.empty?

          locations_by_street = locations(row)
          if locations_by_street.empty?
            LogActivity.save(
              "Nie odnaleziono lokalizacji rekordu '#{excel.cell(row, 1)} #{excel.cell(row, 3)}'"
            )
          end
          locations_by_street.each do |location|
            waste = Waste.new(data(row, location))
            LogActivity.save(waste) unless waste.save
          end
        end
      end
    end
    # rubocop:enable all

    private

    # rubocop:disable Metrics/MethodLength
    def data(row, location)
      {
        kind: 4,
        group_id: group_id,
        street: location.full_address,
        area: params['area'],
        location: location,
        data: {
          info: excel.cell(row, 2),
          number: excel.cell(row, 3),
          area: excel.cell(row, 4),
          group_name: group_name,
          weekday: {
            dry: weekday(row, 5),
            wet: weekday(row, 11),
            mixed: weekday(row, 17)
          }
        }
      }
    end
    # rubocop:enable Metrics/MethodLength

    def locations(row)
      Location.parse_numbers(excel.cell(row, 1), excel.cell(row, 3).to_s)
    end

    def weekday(row, waste_col)
      (1..6).each_with_object([]) do |col, result|
        result << col if excel.cell(row, (col + waste_col - 1)).present?
      end
    end

    def group_name
      excel.default_sheet.downcase.include?('jedno') ? 'Jednorodzinne' : 'Wielolokalowe'
    end

    def group_id
      group_name == 'Jednorodzinne' ? 1 : 2
    end

    def sheets_names
      if params[:area] == 'area5'
        %w( Jednorodzinne Wielolokalowe )
      else
        %w( jedno wielolok )
      end
    end
  end
end
