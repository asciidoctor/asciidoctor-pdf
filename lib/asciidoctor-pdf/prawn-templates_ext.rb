class Prawn::Document
  # NOTE allows prawn-templates 0.0.4 to be used with prawn >= 2.2.0
  const_set :VALID_OPTIONS, (send :remove_const, :VALID_OPTIONS).dup if VALID_OPTIONS.frozen?
end
require 'prawn/templates'
