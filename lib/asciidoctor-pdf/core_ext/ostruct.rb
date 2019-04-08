class OpenStruct
  def delete key
    begin
      delete_field key
    rescue ::NameError
    end
  end unless method_defined? :delete
end
