# ActiveAdmin (app/admin/) hardcodes its controllers to inherit ::ApplicationController, so this
# must be full-stack; GraphqlController opts out and inherits ActionController::API directly.
class ApplicationController < ActionController::Base
end
