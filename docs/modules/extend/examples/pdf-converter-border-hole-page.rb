class PDFConverterCustomTitlePage < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'
  def ink_title_page(doc)
    super
    write_mergin_border line_offset: 5, line_width: 1
    write_header_border line_offset: 5, line_width: 1
  end

  def ink_running_content(*)
    write_mergin_border line_offset: 5, line_width: 1
    write_header_border line_offset: 5, line_width: 1
    super
  end
end

def write_header_border(line_offset:, line_width:)
  _m_t, m_r, m_b, m_l = page_margin
  header_height = theme.header_height
  header_columns = theme.header_columns
  mh_t, mh_r, _mh_b, mh_l = theme.header_margin

  columns = header_columns.delete('^0-9,.').split(',').map(&:to_f)

  o_sum = columns.sum
  sum = 0
  ps = []
  columns.pop
  columns.each do |col|
    sum += col
    ps << sum
  end
  ps = ps.map { |col| col / o_sum }

  p_t = -(page_height - (mh_t - line_offset) - m_b)
  p_b = -(page_height - (mh_t + line_offset) - m_b - header_height)
  p_l = -line_offset
  p_r = page_width - (m_r - line_offset) - m_l

  t_width = page_width - mh_r - mh_l

  p_vs = ps.map do |i|
    t_width * i - m_l + mh_l
  end

  move_cursor_to 0
  stroke_horizontal_rule '000000', line_width: line_width, at: p_t, left_projection: line_offset,
                                   right_projection: -line_offset
  stroke_horizontal_rule '000000', line_width: line_width, at: p_b, left_projection: line_offset,
                                   right_projection: -line_offset
  p_vs.each do |p_v|
    stroke_vertical_line(-p_b, -p_t, at: p_v)
  end
  stroke_vertical_line(-p_b, -p_t, at: p_l)
  stroke_vertical_line(-p_b, -p_t, at: p_r)
end

def write_mergin_border(line_offset:, line_width:)
  m_t, m_r, m_b, m_l = page_margin

  p_t = -(page_height - (m_t - line_offset) - m_b)
  p_b = line_offset
  p_l = -line_offset
  p_r = page_width - (m_r - line_offset) - m_l

  move_cursor_to 0
  stroke_horizontal_rule '000000', line_width: line_width, at: p_t, left_projection: line_offset,
                                   right_projection: -line_offset
  stroke_horizontal_rule '000000', line_width: line_width, at: p_b, left_projection: line_offset,
                                   right_projection: -line_offset
  stroke_vertical_rule '000000', line_width: line_width, at: p_l, top_projection: line_offset,
                                 bottom_projection: line_offset
  stroke_vertical_rule '000000', line_width: line_width, at: p_r, top_projection: line_offset,
                                 bottom_projection: line_offset
end
