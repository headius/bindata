#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "common"))

describe BinData::IO, "reading from non seekable stream" do
  before do
    @rd, @wr = IO::pipe
    @io = BinData::IO.new(@rd)
    @wr.write "a" * 5000
    @wr.write "b" * 5000
    @wr.close
  end

  after do
    @rd.close
  end

  it "always has an offset of 0" do
    @io.readbytes(10)
    @io.offset.must_equal 0
  end

  it "seeks correctly" do
    @io.seekbytes(4999)
    @io.readbytes(5).must_equal "abbbb"
  end

  it "returns zero for num bytes remaining" do
    @io.num_bytes_remaining.must_equal 0
  end
end

describe BinData::IO, "when reading" do
  let(:stream) { StringIO.new "abcdefghij" }
  let(:io) { BinData::IO.new(stream) }

  it "wraps strings in StringIO" do
    io.raw_io.class.must_equal StringIO
  end

  it "does not wrap IO objects" do
    io.raw_io.must_equal stream
  end

  it "raises error when io is BinData::IO" do
    lambda {
      BinData::IO.new(BinData::IO.new(""))
    }.must_raise ArgumentError
  end

  it "returns correct offset" do
    stream.seek(3, IO::SEEK_CUR)

    io.offset.must_equal 0
    io.readbytes(4).must_equal "defg"
    io.offset.must_equal 4
  end

  it "seeks correctly" do
    io.seekbytes(2)
    io.readbytes(4).must_equal "cdef"
  end

  it "reads all bytes" do
    io.read_all_bytes.must_equal "abcdefghij"
  end

  it "returns number of bytes remaining" do
    stream_length = io.num_bytes_remaining

    io.readbytes(4)
    io.num_bytes_remaining.must_equal stream_length - 4
  end

  it "raises error when reading at eof" do
    io.seekbytes(10)
    lambda {
      io.readbytes(3)
    }.must_raise EOFError
  end

  it "raises error on short reads" do
    lambda {
      io.readbytes(20)
    }.must_raise IOError
  end
end

describe BinData::IO, "when writing" do
  let(:stream) { StringIO.new }
  let(:io) { BinData::IO.new(stream) }

  it "does not wrap IO objects" do
    io.raw_io.must_equal stream
  end

  it "raises error when io is BinData::IO" do
    lambda {
      BinData::IO.new(BinData::IO.new(""))
    }.must_raise ArgumentError
  end

  it "writes correctly" do
    io.writebytes("abcd")

    stream.value.must_equal "abcd"
  end

  it "flushes" do
    io.writebytes("abcd")
    io.flush

    stream.value.must_equal "abcd"
  end
end

describe BinData::IO, "reading bits in big endian" do
  let(:b1) { 0b1111_1010 }
  let(:b2) { 0b1100_1110 }
  let(:b3) { 0b0110_1010 }
  let(:io) { BinData::IO.new([b1, b2, b3].pack("CCC")) }

  it "reads a bitfield less than 1 byte" do
    io.readbits(3, :big).must_equal 0b111
  end

  it "reads a bitfield more than 1 byte" do
    io.readbits(10, :big).must_equal 0b1111_1010_11
  end

  it "reads a bitfield more than 2 bytes" do
    io.readbits(17, :big).must_equal 0b1111_1010_1100_1110_0
  end

  it "reads two bitfields totalling less than 1 byte" do
    io.readbits(5, :big).must_equal 0b1111_1
    io.readbits(2, :big).must_equal 0b01
  end

  it "reads two bitfields totalling more than 1 byte" do
    io.readbits(6, :big).must_equal 0b1111_10
    io.readbits(8, :big).must_equal 0b10_1100_11
  end

  it "reads two bitfields totalling more than 2 bytes" do
    io.readbits(7, :big).must_equal 0b1111_101
    io.readbits(12, :big).must_equal 0b0_1100_1110_011
  end

  it "ignores unused bits when reading bytes" do
    io.readbits(3, :big).must_equal 0b111
    io.readbytes(1).must_equal [b2].pack("C")
    io.readbits(2, :big).must_equal 0b01
  end

  it "resets read bits to realign stream to next byte" do
    io.readbits(3, :big).must_equal 0b111
    io.reset_read_bits
    io.readbits(3, :big).must_equal 0b110
  end
end

describe BinData::IO, "reading bits in little endian" do
  let(:b1) { 0b1111_1010 }
  let(:b2) { 0b1100_1110 }
  let(:b3) { 0b0110_1010 }
  let(:io) { BinData::IO.new([b1, b2, b3].pack("CCC")) }

  it "reads a bitfield less than 1 byte" do
    io.readbits(3, :little).must_equal 0b010
  end

  it "reads a bitfield more than 1 byte" do
    io.readbits(10, :little).must_equal 0b10_1111_1010
  end

  it "reads a bitfield more than 2 bytes" do
    io.readbits(17, :little).must_equal 0b0_1100_1110_1111_1010
  end

  it "reads two bitfields totalling less than 1 byte" do
    io.readbits(5, :little).must_equal 0b1_1010
    io.readbits(2, :little).must_equal 0b11
  end

  it "reads two bitfields totalling more than 1 byte" do
    io.readbits(6, :little).must_equal 0b11_1010
    io.readbits(8, :little).must_equal 0b00_1110_11
  end

  it "reads two bitfields totalling more than 2 bytes" do
    io.readbits(7, :little).must_equal 0b111_1010
    io.readbits(12, :little).must_equal 0b010_1100_1110_1
  end

  it "ignores unused bits when reading bytes" do
    io.readbits(3, :little).must_equal 0b010
    io.readbytes(1).must_equal [b2].pack("C")
    io.readbits(2, :little).must_equal 0b10
  end

  it "resets read bits to realign stream to next byte" do
    io.readbits(3, :little).must_equal 0b010
    io.reset_read_bits
    io.readbits(3, :little).must_equal 0b110
  end
end

class BitWriterHelper
  def initialize
    @stringio = BinData::IO.create_string_io
    @io = BinData::IO.new(@stringio)
  end

  def writebits(val, nbits, endian)
    @io.writebits(val, nbits, endian)
  end

  def writebytes(val)
    @io.writebytes(val)
  end

  def value
    @io.flushbits
    @stringio.rewind
    @stringio.read
  end
end

describe BinData::IO, "writing bits in big endian" do
  let(:io) { BitWriterHelper.new }

  it "writes a bitfield less than 1 byte" do
    io.writebits(0b010, 3, :big)
    io.value.must_equal [0b0100_0000].pack("C")
  end

  it "writes a bitfield more than 1 byte" do
    io.writebits(0b10_1001_1101, 10, :big)
    io.value.must_equal [0b1010_0111, 0b0100_0000].pack("CC")
  end

  it "writes a bitfield more than 2 bytes" do
    io.writebits(0b101_1000_0010_1001_1101, 19, :big)
    io.value.must_equal [0b1011_0000, 0b0101_0011, 0b1010_0000].pack("CCC")
  end

  it "writes two bitfields totalling less than 1 byte" do
    io.writebits(0b1_1001, 5, :big)
    io.writebits(0b00, 2, :big)
    io.value.must_equal [0b1100_1000].pack("C")
  end

  it "writes two bitfields totalling more than 1 byte" do
    io.writebits(0b01_0101, 6, :big)
    io.writebits(0b001_1001, 7, :big)
    io.value.must_equal [0b0101_0100, 0b1100_1000].pack("CC")
  end

  it "writes two bitfields totalling more than 2 bytes" do
    io.writebits(0b01_0111, 6, :big)
    io.writebits(0b1_0010_1001_1001, 13, :big)
    io.value.must_equal [0b0101_1110, 0b0101_0011, 0b0010_0000].pack("CCC")
  end

  it "pads unused bits when writing bytes" do
    io.writebits(0b101, 3, :big)
    io.writebytes([0b1011_1111].pack("C"))
    io.writebits(0b01, 2, :big)

    io.value.must_equal [0b1010_0000, 0b1011_1111, 0b0100_0000].pack("CCC")
  end
end

describe BinData::IO, "writing bits in little endian" do
  let(:io) { BitWriterHelper.new }

  it "writes a bitfield less than 1 byte" do
    io.writebits(0b010, 3, :little)
    io.value.must_equal [0b0000_0010].pack("C")
  end

  it "writes a bitfield more than 1 byte" do
    io.writebits(0b10_1001_1101, 10, :little)
    io.value.must_equal [0b1001_1101, 0b0000_0010].pack("CC")
  end

  it "writes a bitfield more than 2 bytes" do
    io.writebits(0b101_1000_0010_1001_1101, 19, :little)
    io.value.must_equal [0b1001_1101, 0b1000_0010, 0b0000_0101].pack("CCC")
  end

  it "writes two bitfields totalling less than 1 byte" do
    io.writebits(0b1_1001, 5, :little)
    io.writebits(0b00, 2, :little)
    io.value.must_equal [0b0001_1001].pack("C")
  end

  it "writes two bitfields totalling more than 1 byte" do
    io.writebits(0b01_0101, 6, :little)
    io.writebits(0b001_1001, 7, :little)
    io.value.must_equal [0b0101_0101, 0b0000_0110].pack("CC")
  end

  it "writes two bitfields totalling more than 2 bytes" do
    io.writebits(0b01_0111, 6, :little)
    io.writebits(0b1_0010_1001_1001, 13, :little)
    io.value.must_equal [0b0101_0111, 0b1010_0110, 0b0000_0100].pack("CCC")
  end

  it "pads unused bits when writing bytes" do
    io.writebits(0b101, 3, :little)
    io.writebytes([0b1011_1111].pack("C"))
    io.writebits(0b01, 2, :little)

    io.value.must_equal [0b0000_0101, 0b1011_1111, 0b0000_0001].pack("CCC")
  end
end

describe BinData::IO, "with changing endian" do
  it "does not mix different endianess when reading" do
    b1 = 0b0110_1010
    b2 = 0b1110_0010
    str = [b1, b2].pack("CC")
    io = BinData::IO.new(str)

    io.readbits(3, :big).must_equal 0b011
    io.readbits(4, :little).must_equal 0b0010
  end

  it "does not mix different endianess when writing" do
    io = BitWriterHelper.new
    io.writebits(0b110, 3, :big)
    io.writebits(0b010, 3, :little)
    io.value.must_equal [0b1100_0000, 0b0000_0010].pack("CC")
  end
end
