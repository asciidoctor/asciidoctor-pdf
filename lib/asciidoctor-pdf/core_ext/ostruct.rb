class OpenStruct
  def [] key
    send key
  end unless respond_to? :[]

  def []= key, val
    send %(#{key}=), val
  end unless respond_to? :[]=
end
