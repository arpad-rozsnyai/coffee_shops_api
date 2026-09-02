class GraphqlController < ApplicationController
  def execute
    result = CoffeeShopsApiSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      operation_name: params[:operationName]
    )

    render json: result
  end

  private

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
