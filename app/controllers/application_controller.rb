class ApplicationController < ActionController::API
 rescue_from ActiveRecord::RecordNotFound do
  render json: { error: "Recurso não encontrado" }, status: :not_found
 end
 rescue_from ActionController::ParameterMissing do |error|
  render json: { error: error.message }, status: :unprocessable_entity
 end
end
