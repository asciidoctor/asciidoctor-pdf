class OpenStruct
  def [] key
    send key
  end unless method_defined? :[]

  def []= key, val
    send %(#{key}=), val
  end unless method_defined? :[]=
end if RUBY_ENGINE == 'rbx' || RUBY_VERSION < '2.0.0'

class OpenStruct
  def delete key
    (@table.key? key) ? (delete_field key) : nil
  end
end
