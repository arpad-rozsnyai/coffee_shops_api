class GraphqlController < ApplicationController
  def execute
    result = CoffeeShopsApiSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      operation_name: params[:operationName],
      context: { current_user: current_user }
    )

    render json: result
  end

  private

  # nil (rather than raising) for a missing/invalid/expired token - unauthenticated requests are
  # rejected by each query field's own Types::QueryType#authenticate!, not here, so login/refreshToken
  # stay reachable without one.
  def current_user
    return nil if bearer_token.blank?

    JwtDecoder.new(token: bearer_token, expected_type: :access).call
  rescue JwtDecoder::InvalidTokenError
    nil
  end

  def bearer_token
    request.headers["Authorization"]&.slice(/\ABearer (.+)\z/, 1)
  end

  def prepare_variables(variables_param)
    case variables_param
    when String
      variables_param.present? ? JSON.parse(variables_param) : {}
    when ActionController::Parameters
      variables_param.to_unsafe_hash
    when Hash
      variables_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end
end
