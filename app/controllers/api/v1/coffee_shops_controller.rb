module Api
  module V1
    class CoffeeShopsController < ApplicationController
      rescue_from CsvClient::RemoteDataSourceError, CsvParser::ParseError, with: :render_data_source_unavailable

      def index
        validation = CoordinateValidator.call(x: params[:x], y: params[:y])
        return render_validation_errors(validation) unless validation[:errors].empty?

        results = NearestCoffeeShopsFinder.new.call(x: validation[:x], y: validation[:y])
        render json: CoffeeShopDistanceSerializer.new(results)
      end

      private

      def render_validation_errors(validation)
        errors = validation[:errors].map do |error|
          {
            status: "400",
            title: "Invalid Parameter",
            detail: error[:detail],
            source: { parameter: error[:attribute].to_s }
          }
        end

        render_errors(errors, status: :bad_request)
      end

      def render_data_source_unavailable
        errors = [
          {
            status: "503",
            title: "Data Source Unavailable",
            detail: "Coffee shop data is temporarily unavailable."
          }
        ]

        render_errors(errors, status: :service_unavailable)
      end

      def render_errors(errors, status:)
        render json: { errors: errors }, status: status
      end
    end
  end
end
