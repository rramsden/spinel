# FFI plumbing verification (commit #1)
#
# Sanity-checks the `ptr` scalar type wiring in the compiler backend.
# Loads spinel_codegen.rb under CRuby, inspects Compiler's type-dispatch
# methods directly. NOT part of `make test`; this is a dev-loop check
# for codegen-internal invariants we can't easily exercise end-to-end
# until the FFI DSL is wired up.
#
# Usage: ruby test/ffi/check_ptr_wiring.rb
# Exit 0 on pass, non-zero with message on failure.

# spinel_codegen.rb runs its CLI driver at load time if ARGV has an arg;
# pass no args and trap its exit(1) by eval'ing just the class body.
codegen_src = File.read(File.expand_path("../../spinel_codegen.rb", __dir__))
# Strip the "---- Main ----" section (everything from its marker onward).
main_marker = "# ---- Main ----"
idx = codegen_src.index(main_marker)
raise "couldn't find Main marker" unless idx
eval(codegen_src[0...idx])

c = Compiler.allocate

failures = []

got = c.c_type("ptr")
failures << "c_type(ptr) expected 'void *' got #{got.inspect}" unless got == "void *"

got = c.type_is_pointer("ptr")
failures << "type_is_pointer(ptr) expected 0 got #{got.inspect}" unless got == 0

got = c.c_default_val("ptr")
failures << "c_default_val(ptr) expected 'NULL' got #{got.inspect}" unless got == "NULL"

got = c.is_nullable_pointer_type("ptr")
failures << "is_nullable_pointer_type(ptr) expected 1 got #{got.inspect}" unless got == 1

# Nullable ptr (ptr?) should unwrap correctly
got = c.c_type("ptr?")
failures << "c_type(ptr?) expected 'void *' got #{got.inspect}" unless got == "void *"

got = c.type_is_pointer("ptr?")
failures << "type_is_pointer(ptr?) expected 0 got #{got.inspect}" unless got == 0

# Regression checks on existing types
got = c.c_type("int")
failures << "c_type(int) regression: got #{got.inspect}" unless got == "mrb_int"

got = c.c_type("string")
failures << "c_type(string) regression: got #{got.inspect}" unless got == "const char *"

got = c.type_is_pointer("int")
failures << "type_is_pointer(int) regression: got #{got.inspect}" unless got == 0

got = c.type_is_pointer("string")
failures << "type_is_pointer(string) regression: got #{got.inspect}" unless got == 1

if failures.empty?
  puts "ffi ptr wiring OK (10 assertions passed)"
  exit 0
else
  $stderr.puts "ffi ptr wiring FAILED:"
  failures.each { |f| $stderr.puts "  - #{f}" }
  exit 1
end
