class OpenStruct
  def [] key
    send key
  end

  def []= key, val
    send %(#{key}=), val
  end
end if RUBY_VERSION < '2.0.0'
