#!/usr/bin/env ruby

# Creates the data structures needed by Onigurma to map Unicode codepoints to
# property names

unless ARGV.size == 1
  $stderr.puts "Usage: #{$0} UnicodeData.txt"
  exit(1)
end

data = {'Cn' => []}
last_cp = 0
ARGF.lines do |line|
  fields = line.split(';')
  cp = fields[0].to_i(16)

  # The Cn category represents unassigned characters. These are not listed in
  # UnicodeData.txt so we must derive them by looking for 'holes' in the range
  # of listed codepoints. We increment the last codepoint seen and compare it
  # with the current codepoint. If the current codepoint is less than
  # last_cp.next we have found a hole, so we add the missing codepoint to the
  # Cn category.
  while ((last_cp = last_cp.next) < cp)
    data['Cn'] << last_cp
  end

  # The third field denotes the 'General' category, e.g. Lu
  (data[fields[2]] ||= []) << cp
  
  # The 'Major' category is the first letter of the 'General' category, e.g.
  # 'Lu' -> 'L'
  (data[fields[2][0]] ||= []) << cp
  last_cp = cp
end

# The last Cn codepoint should be 0x10ffff. If it's not, append the missing
# codepoints
data['Cn'] += (data['Cn'].last..0x10ffff).to_a

data.sort.each do |prop, codepoints|
  
  # We have a sorted Array of codepoints that we wish to partition into
  # ranges such that the start- and endpoints form an inclusive set of
  # codepoints with property _property_. Note: It is intended that some ranges
  # will begin with the value with  which they end, e.g. 0x0020 -> 0x0020
  
  last_cp = codepoints.first
  pairs = [[last_cp, nil]]
  codepoints[1..-1].each do |codepoint|
    
    # If the current codepoint does not follow directly on from the last
    # codepoint, the last codepoint represents the end of the current range,
    # and the current codepoint represents the start of the next range.
    if last_cp.next != codepoint
      pairs[-1][-1] = last_cp
      pairs << [codepoint, nil]
    end
    last_cp = codepoint
  end

  # The final pair has as its endpoint the last codepoint for this property
  pairs[-1][-1] = codepoints.last
  
  puts "\n/* '#{prop}': #{prop.size == 2 ? 'General' : 'Major'} Category */"
  puts "static const OnigCodePoint CR_#{prop}[] = {"
  # The first element of the constant is the number of pairs of codepoints
  puts "\t#{pairs.size},"
  pairs.map{|pair| pair.map {|c| sprintf("%0#6x", c)}}.each do |cp|
    puts "\t#{cp.first}, #{cp.last},"
  end
  puts "}; /* CR_#{prop} */"
end
