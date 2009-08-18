require 'pp'
def dump_cat(codepoints, prop)
  puts "\n/* '#{prop}': #{prop.size == 2 ? 'General' : 'Major'} Category */"
  puts "static const OnigCodePoint CR_#{prop}[] = {"
  puts "\t#{codepoints.size},"
  codepoints.map{|pair| pair.map {|c| sprintf("%0#6x", c)}}.each do |cp|
    puts "\t#{cp.first}, #{cp.last},"
  end
  puts "}; /* CR_#{prop} */"
end
data = {'Cn' => []}
last_cp = 0

ARGF.lines do |line|
  fields = line.split(';')
  cp = fields[0].to_i(16)
  while ((last_cp = last_cp.next) < cp)
    data['Cn'] << last_cp
  end
  # General category
  (data[fields[2]] ||= []) << cp
  # Major category
  (data[fields[2][0]] ||= []) << cp
  last_cp = cp
end

data['Cn'] += (data['Cn'].last..0x10ffff).to_a
data.sort.each do |property, codepoints|
  codepoints.sort!
  last_cp = codepoints.first
  pairs = [[last_cp, nil]]
  codepoints[1..-1].each do |codepoint|
    if last_cp.next != codepoint
      pairs[-1][-1] = last_cp
      pairs << [codepoint, nil]
    end
    last_cp = codepoint
  end
  pairs[-1][-1] = codepoints.last
  dump_cat(pairs, property)
end
