class OpenStruct
  def [] key
    send key
  end unless respond_to? :[]

  def []= key, val
    send %(#{key}=), val
  end unless respond_to? :[]=
end if RUBY_ENGINE == 'rbx' || RUBY_VERSION < '2.0.0'
