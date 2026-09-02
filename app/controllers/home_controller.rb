# The rest of this app is API-only (ApplicationController < ActionController::API),
# which strips out HTML view rendering entirely — it can't render a template even
# via an explicit `render`. This one controller serves an actual HTML page, so it
# opts back into the full controller stack instead.
class HomeController < ActionController::Base
  def index
  end
end
