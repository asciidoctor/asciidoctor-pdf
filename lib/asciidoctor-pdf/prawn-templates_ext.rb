# unfreeze Prawn::Document::VALID_OPTIONS for prawn-templates
Prawn::Document.const_set :VALID_OPTIONS, (Prawn::Document.send :remove_const, :VALID_OPTIONS).dup
require 'prawn/templates'
