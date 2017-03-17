# unfreeze Prawn::Document::VALID_OPTIONS for prawn-templates
class Prawn::Document
  const_set :VALID_OPTIONS, (send :remove_const, :VALID_OPTIONS).dup if VALID_OPTIONS.frozen?
end
require 'prawn/templates'
