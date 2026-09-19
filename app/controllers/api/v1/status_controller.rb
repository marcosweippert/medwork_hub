module Api
  module V1
    class StatusController < BaseController
      def show
        render json: {
          ok: true,
          clinic: Setting.current.clinic_name,
          key: @current_api_key.name
        }
      end
    end
  end
end
