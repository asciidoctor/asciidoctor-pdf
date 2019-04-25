class Regexp
  alias match? === unless Regexp.method_defined? :match?
end
