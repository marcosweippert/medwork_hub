module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_key!

      private

      def authenticate_api_key!
        raw = bearer_token.presence || request.headers["X-Api-Key"].presence || params[:api_key]
        @current_api_key = ApiKey.authenticate(raw)
        if @current_api_key
          @current_api_key.touch_usage!
        else
          render json: { error: "unauthorized" }, status: :unauthorized
        end
      end

      def bearer_token
        header = request.headers["Authorization"].to_s
        header.delete_prefix("Bearer ").presence
      end
    end
  end
end
