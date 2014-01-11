######################################################################
#
# This file was copied from Prawn (manual/syntax_highlight.rb) and
# modified for use with Asciidoctor PDF.
# 
# Prawn is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Prawn is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Prawn. If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) Felipe Doria
# Copyrigth (C) 2014 OpenDevise, Inc.
#
######################################################################

require 'coderay'

# Registers a to_prawn method with CodeRay. The method returns an array of hashes to be
# used with Prawn::Text.formatted_text(array).
#
# Usage:
#
# CodeRay.scan(string, :ruby).to_prawn
#
module Asciidoctor
module Prawn
class CodeRayEncoder < ::CodeRay::Encoders::Encoder
  register_for :to_prawn

  # Manni theme from Pygments
  COLORS = {
    default:           '333333',

    annotation:        '9999FF',
    attribute_name:    '4F9FCF',
    attribute_value:   'D44950',
    class:             '00AA88',
    class_variable:    '003333',
    color:             'FF6600',
    comment:           '999999',
    constant:          '336600',
    directive:         '006699',
    doctype:           '009999',
    instance_variable: '003333',
    integer:           'FF6600',
    entity:            '999999',
    float:             'FF6600',
    function:          'CC00FF',
    important:         '9999FF',
    inline_delimiter:  'EF804F',
    instance_variable: '003333',
    key:               '006699',
    keyword:           '006699',
    method:            'CC00FF',
    namespace:         '00CCFF',
    predefined_type:   '007788',
    regexp:            '33AAAA',
    string:            'CC3300',
    symbol:            'FFCC33',
    tag:               '2F6F9F',
    type:              '007788',
    value:             '336600'
  }

  def setup(options)
    super
    @out  = []
    @open = []
  end

  def text_token(text, kind)
    color = COLORS[kind] || COLORS[@open.last] || COLORS[:default]
    
    @out << {:text => text, :color => color}
  end

  def begin_group(kind)
    @open << kind
  end

  def end_group(kind)
    @open.pop
  end
end
end
end
