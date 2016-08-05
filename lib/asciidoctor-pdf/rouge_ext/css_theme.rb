module Rouge
class CSSTheme
  # Patch style_for to return most specific style first
  # See https://github.com/jneen/rouge/issues/280
  # Fixed as of rouge v1.10.0
  def style_for token
    token.token_chain.reverse_each do |t|
      if (s = styles[t])
        return s
      end
    end
    nil
  end
end
end if (Gem::Version.new Rouge.version) < (Gem::Version.new '1.10.0')
