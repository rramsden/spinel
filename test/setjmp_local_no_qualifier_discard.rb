# Regression: a typed-pointer toplevel local must pass to instance
# methods without -Wdiscarded-qualifiers when the program also raises
# (which flips @needs_setjmp on and gates the volatile codegen for
# toplevel locals). Tests build with -Werror, so a return to
# `volatile T *lv` (qualifying the pointee) would fail this test.
#
# Box has a setter so it doesn't get value-type-optimized into a
# struct-by-value: we need it to land in main() as a typed pointer
# local, which is the only shape that exercises the volatile pointer
# qualifier path.

class Box
  def initialize(n)
    @n = n
  end

  def n=(v)
    @n = v
  end

  def value
    @n
  end
end

# Defining a method that raises is enough to set @needs_setjmp = 1
# at codegen time — the call doesn't have to actually fire.
def boom
  raise "unreachable"
end

b = Box.new(42)
b.n = 7
puts b.value
