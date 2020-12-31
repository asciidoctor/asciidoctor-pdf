# frozen_string_literal: true

Prawn::Graphics::Patterns.prepend (Module.new do
  def parse_gradient_arguments *args, **kwargs
    if args.length == 1 && Hash === (actual_kwargs = args[0]) && kwargs.empty?
      super(**actual_kwargs)
    else
      super
    end
  end
end) if (Gem::Version.new RUBY_VERSION) >= (Gem::Version.new '3.0.0')
