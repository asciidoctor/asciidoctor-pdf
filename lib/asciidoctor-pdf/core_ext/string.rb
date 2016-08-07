class String
  def pred
    begin
      # integers
      %(#{(Integer self) - 1})
    rescue ::ArgumentError
      # chars (upper alpha, lower alpha, lower greek)
      ([65, 97, 945].include? ord) ? '0' : ([ord - 1].pack 'U*')
    end
  end unless respond_to? :pred
end
