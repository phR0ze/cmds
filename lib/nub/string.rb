#MIT License
#Copyright (c) 2018 phR0ze
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

ColorPair = Struct.new(:str, :color_code, :color_name)
ColorMap = {
  30 => "black",
  31 => "red",
  32 => "green",
  33 => "yellow",
  34 => "blue",
  35 => "magenta",
  36 => "cyan",
  37 => "white",
  39 => "gray88"   # default
}

# Monkey patch string with some useful methods
class String

  # Convert the string to ascii, stripping out or converting all non-ascii characters
  def to_ascii
    options = {
      :invalid => :replace,
      :undef => :replace,
      :replace => '',
      :universal_newline => true
    }
    return self.encode(Encoding.find('ASCII'), options)
  end

  # Strip the ansi color codes from the given string
  # @returns [String] string without any ansi codes
  def strip_color
    return self.gsub(/\e\[0;[39]\d;49m/, '').gsub(/\e\[0m/, '')
  end

  # Tokenize the given colorized string
  # @returns [Array] array of Token
  def tokenize_color
    tokens = []
    matches = self.to_enum(:scan, /\e\[0;[39]\d;49m(.*?[\s]*)\e\[0m/).map{Regexp.last_match}

    i, istart, iend = 0, 0, 0
    match = matches[i]
    while istart < self.size
      color = "39"
      iend = self.size
      token = self[istart..iend]

      # Current token is not a match
      if match && match.begin(0) != istart
        iend = match.begin(0)-1
        token = self[istart..iend]
        istart = iend + 1

      # Current token is a match
      elsif match && match.begin(0) == istart
        iend = match.end(0)
        token = match.captures.first
        color = match.to_s[/\e\[0;(\d+);49m.*/, 1]
        i += 1; match = matches[i]
        istart = iend

      # Ending
      else
        istart = iend
      end

      # Create token and advance
      tokens << ColorPair.new(token, color.to_i, ColorMap[color.to_i])
    end

    return tokens
  end


end

# vim: ft=ruby:ts=2:sw=2:sts=2
