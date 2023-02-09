require 'rubyserial'

module MX25328
  def MX25328.connect *args
    Connection.new(*args)
  end

  # Manage serialport connection
  class Connection
    def initialize path='/dev/ttyUSB0'
      @channel = Serial.new(path, 2400, 8, :none, 1)
      @remaining = []
    end

    # Read `frames` number of data frames from the channel
    def read frames=2**28
      (@remaining + @channel.read(frames*14).unpack('C*'))
        .slice_before(&Frame.method(:is_first_byte))
        .drop_while { |bytes| not Frame.is_first_byte(bytes[0]) }
        .take_while { |bytes| bytes.size % 14 == 0 ? (@remaining = []) && true : (@remaining = bytes) && false }
        .map(&Frame.method(:new))
    end

    # Close the channel
    def close
      @channel.close
    end
  end

  # Represent a 14-byte long data frame
  class Frame
    # Return whether the given byte is the "first" byte of a data frame
    def Frame.is_first_byte byte
      byte >> 4 == 1
    end

    # Convert "tube" bits to numerals
    #
    # Tube codes:
    #
    #  AAA
    # F   B
    #  GGG
    # E   C
    #  DDD
    #
    # "L" shape (F+E+D) means infinity
    # " " shape is the empty, thus 0.0
    def Frame.tube_to_numeric msb, lsb
      # msb: indifferent | e | f | a
      # lsb: d | c | g | b
      bits = ((msb & 7) << 4) | (lsb & 15)

      index = [
        ##EFADCGB
        0b1111101,
        0b0000101, 
        0b1011011,
        0b0011111,
        0b0100111,
        0b0111110,
        0b1111110,
        0b0010101,
        0b1111111,
        0b0111111,
        0b0000000,
        0b1101000,
      ].find_index { |mask| mask ^ bits == 0 }

      raise 'not a number %b %b %b' % [ bits, msb, lsb ] unless index
      return 0.0 if index == 10
      return Float::INFINITY if index == 11
      return index.to_f
    end

    attr_reader :number, :unit

    def initialize bytes
      b1, b2, b3, b4, b5, b6, b7, b8, b9, ba, bb, bc, bd, be = bytes

      @raw = 0.0

      # (1) AC | DC | AUTO | RS232
      @ac = b1 & 8 > 0
      @dc = b1 & 4 > 0
      @auto = b1 & 2 > 0
      @rs232 = b1 & 1 > 0

      # (2) "+" or "-" | 1000e | 1000f | 1000a
      # (3) 1000d | 1000c | 1000g | 1000b
      negative = b2 & 8 > 0
      @raw += Frame.tube_to_numeric(b2, b3) * 1000

      # (4) decimal in front of 100 | 100e | 100f | 100a
      # (5) 100d | 100c | 100g | 100b
      decimal_hundred = b4 & 8 > 0
      @raw += Frame.tube_to_numeric(b4, b5) * 100

      # (6) decimal in front of 10 | 10e | 10f | 10a
      # (7) 10d | 10c | 10g | 10b
      decimal_ten = b6 & 8 > 0
      @raw += Frame.tube_to_numeric(b6, b7) * 10

      # (8) decimal in front of 1 | 1e | 1f | 1a
      # (9) 1d | 1c | 1g | 1b
      decimal_one = b8 & 8 > 0
      @raw += Frame.tube_to_numeric(b8, b9)

      # (A) u | n | k | diode
      @u = ba & 8 > 0
      @n = ba & 4 > 0
      @k = ba & 2 > 0
      @diode = ba & 1 > 0

      # (B) m | % | M | BEEP
      @m = bb & 8 > 0
      @percent = bb & 4 > 0
      @M = bb & 2 > 0
      @beep = bb & 1 > 0

      # (C) F | Ω | REL | HOLD
      @F = bc & 8 > 0
      @ohm = bc & 4 > 0
      @rel = bc & 2 > 0
      @hold = bc & 1 > 0

      # (D) A | V | Hz | battery icon
      @A = bd & 8 > 0
      @V = bd & 4 > 0
      @Hz = bd & 2 > 0
      @battery = bd & 2 > 0

      # (E) empty | mV | °C | empty
      @mV = be & 4 > 0
      @celsius = be & 2 > 0

      # transform raw number according to flags
      @raw *= (negative ? -1 : 1)
      if decimal_hundred
        @raw /= 1000.0
      elsif decimal_ten
        @raw /= 100.0
      elsif decimal_one
        @raw /= 10.0
      end

      # transform parsed number according to flags
      @number = @raw
      if @n
        @number /= 10**9
      elsif @u
        @number /= 10**6
      elsif @m or @mV
        @number /= 10**3
      elsif @k
        @number *= 10**3
      elsif @M
        @number *= 10**6
      end

      # compute unit
      @unit = if @ohm
                'Ω'
              elsif @A
                'A'
              elsif @V or @mV
                'V'
              elsif @Hz
                'Hz'
              elsif @celsius
                '°C'
              elsif @F
                'F'
              end
    end

    # Format and return the current data frame values as CSV
    def to_csv
      %{#{number},"#{unit}"}
    end
  end
end
