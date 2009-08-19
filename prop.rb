#!/usr/bin/env ruby

# Creates the data structures needed by Onigurma to map Unicode codepoints to
# property names

unless ARGV.size == 2
  $stderr.puts "Usage: #{$0} UnicodeData.txt Scripts.txt"
  exit(1)
end

unicode_data_f, scripts_f = ARGV

$data = {'Cn' => []}

def parse_unicode_data(file)
  last_cp = 0
  File.open(file).lines.each do |line|
    fields = line.split(';')
    cp = fields[0].to_i(16)

    # The Cn category represents unassigned characters. These are not listed in
    # UnicodeData.txt so we must derive them by looking for 'holes' in the range
    # of listed codepoints. We increment the last codepoint seen and compare it
    # with the current codepoint. If the current codepoint is less than
    # last_cp.next we have found a hole, so we add the missing codepoint to the
    # Cn category.
    while ((last_cp = last_cp.next) < cp)
      $data['Cn'] << last_cp
    end

    # The third field denotes the 'General' category, e.g. Lu
    ($data[fields[2]] ||= []) << cp
    
    # The 'Major' category is the first letter of the 'General' category, e.g.
    # 'Lu' -> 'L'
    ($data[fields[2][0,1]] ||= []) << cp
    last_cp = cp
  end
  # The last Cn codepoint should be 0x10ffff. If it's not, append the missing
  # codepoints
  $data['Cn'] += ($data['Cn'].last.next..0x10ffff).to_a
end


def parse_scripts(file)
  File.open(file).lines.reject{|l| l.match(/^[# ]/)}.each do |line|
    fields = line.split(';')
    next unless fields.size > 1
    script = fields[1][/^ (\w+)/, 1]
    cp = fields.first.strip.split('..').map{|s| s.to_i(16)}
    cp = cp.size == 1 ? cp : (cp.first..cp.last).to_a
    $data[script] ||= []
    $data[script] += cp
  end
end

parse_unicode_data(unicode_data_f)
parse_scripts(scripts_f)


# We now derive the character classes (POSIX brackets), e.g. [[:alpha:]]
#

# alnum    Letter | Mark | Decimal_Number
$data['Alnum'] = $data['L'] + $data['M'] + $data['Nd']

# alpha    Letter | Mark
$data['Alpha'] = $data['L'] + $data['M']

# ascii    0000 - 007F
$data['Ascii'] = (0..0x007F).to_a

# blank    Space_Separator | 0009
$data['Blank'] = $data['Zs'] + [0x0009]

# TODO: Double check this definition. It appears to encompass the entire C
# category, but currently the CR blocks for C and Cntrl are markedly different
# cntrl    Control | Format | Unassigned | Private_Use | Surrogate
$data['Cntrl'] = $data['Cc'] + $data['Cf'] + $data['Cn'] + $data['Co'] + 
                 $data['Cs']

# digit    Decimal_Number
$data['Digit'] = $data['Nd']

# lower    Lowercase_Letter
$data['Lower'] = $data['Ll']

# punct    Connector_Punctuation | Dash_Punctuation | Close_Punctuation |
#          Final_Punctuation | Initial_Punctuation | Other_Punctuation |
#          Open_Punctuation
# NOTE: This definition encompasses the entire P category, and the current
# mappings agree, but we explcitly declare this way to marry it with the above
# definition.
$data['Punct'] = $data['Pc'] + $data['Pd'] + $data['Pe'] + $data['Pf'] + 
                 $data['Pi'] + $data['Po'] + $data['Ps']

# space    Space_Separator | Line_Separator | Paragraph_Separator |
#               0009 | 000A | 000B | 000C | 000D | 0085
$data['Space'] = $data['Zs'] + $data['Zl'] + $data['Zp'] + 
                [0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0085]

# upper    Uppercase_Letter
$data['Upper'] = $data['Lu']

# xdigit   0030 - 0039 | 0041 - 0046 | 0061 - 0066
#          (0-9, a-f, A-F)
$data['Xdigit'] = (0x0030..0x0039).to_a + (0x0041..0x0046).to_a + 
                 (0x0061..0x0066).to_a + ('0'.ord..'9'.ord).to_a + 
                 ('a'.ord..'f'.ord).to_a + ('A'.ord..'F'.ord).to_a

# word     Letter | Mark | Decimal_Number | Connector_Punctuation
$data['Word'] = $data['L'] + $data['M'] + $data['Nd'] + $data['Pc']

# graph    [[:^space:]] && ^Control && ^Unassigned && ^Surrogate
$data['Graph'] = $data['L'] + $data['M'] + $data['N'] + $data['P'] + $data['S']
$data['Graph'] -= $data['Space'] - $data['C']

# print    [[:graph:]] | [[:space:]]
$data['Print'] = $data['Graph'] + $data['Space']

$data.sort.each do |prop, codepoints|
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
