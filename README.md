# What is BinData?

Do you ever find yourself writing code like this?

```ruby
io = File.open(...)
len = io.read(2).unpack("v")
name = io.read(len)
width, height = io.read(8).unpack("VV")
puts "Rectangle #{name} is #{width} x #{height}"
```

It’s ugly, violates DRY and feels like you’re writing Perl, not Ruby.

There is a better way. Here’s how you’d write the above using BinData.

```ruby
class Rectangle < BinData::Record
  endian :little
  uint16 :len
  string :name, :read_length => :len
  uint32 :width
  uint32 :height
end

io = File.open(...)
r  = Rectangle.read(io)
puts "Rectangle #{r.name} is #{r.width} x #{r.height}"
```

BinData makes it easy to create new data types. It supports all the common
primitive datatypes that are found in structured binary data formats. Support
for dependent and variable length fields is built in. 

# Installation

    $ gem install bindata

-or-

    $ sudo ruby setup.rb

# Documentation

[http://bindata.rubyforge.org/manual.html](http://bindata.rubyforge.org/manual.html)

-or-

    $ rake manual

# Contact

If you have any queries / bug reports / suggestions, please contact me
(Dion Mendel) via email at dion@lostrealm.com
