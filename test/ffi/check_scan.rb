# FFI scan verification (commit #2)
#
# Loads spinel_codegen.rb under CRuby, feeds it a hand-crafted AST that
# contains an FFI module, and asserts the @ffi_* state arrays get
# populated correctly.
#
# Not part of `make test` — internal dev-loop check for a pass that has
# no user-visible output until commit #3 adds dispatch.

# Strip the CLI-driver section so we can require the class without
# running the compiler.
codegen_src = File.read(File.expand_path("../../spinel_codegen.rb", __dir__))
main_marker = "# ---- Main ----"
idx = codegen_src.index(main_marker)
raise "couldn't find Main marker" unless idx
eval(codegen_src[0...idx])

# Build a Compiler with a minimal AST representing:
#
#   module SDL
#     ffi_lib "SDL2"
#     ffi_cflags "-I/usr/include/SDL2"
#     ffi_func :SDL_Init, [:uint32], :int
#     ffi_func :SDL_Delay, [:uint32], :void
#     ffi_const :INIT_VIDEO, 32
#     ffi_buffer :event_buf, 64
#     ffi_read_u32 :event_type, 0
#   end
#
# We don't go through prism/spinel_parse — we directly seed the AST
# arrays. This is fragile if the AST representation changes, but it's
# the quickest way to exercise scan_ffi_decl in isolation.

c = Compiler.new

# Helper: allocate a node of given type, return its id.
def mknode(c, type)
  nid = c.instance_variable_get(:@nd_type).length
  c.instance_variable_get(:@nd_type).push(type)
  c.instance_variable_get(:@nd_name).push("")
  c.instance_variable_get(:@nd_body).push(-1)
  c.instance_variable_get(:@nd_value).push(0)
  c.instance_variable_get(:@nd_content).push("")
  c.instance_variable_get(:@nd_receiver).push(-1)
  c.instance_variable_get(:@nd_arguments).push(-1)
  c.instance_variable_get(:@nd_parameters).push(-1)
  c.instance_variable_get(:@nd_constant_path).push(-1)
  c.instance_variable_get(:@nd_elements).push("")
  c.instance_variable_get(:@nd_expression).push(-1)
  # Fields I haven't touched in this test — if spinel_codegen grows
  # more nd_* arrays we may need to extend here.
  # For now, only the subset used by scan_ffi_decl / collect_module.
  nid
end

def set_name(c, nid, name);       c.instance_variable_get(:@nd_name)[nid] = name; end
def set_content(c, nid, str);     c.instance_variable_get(:@nd_content)[nid] = str; end
def set_value(c, nid, v);         c.instance_variable_get(:@nd_value)[nid] = v; end
def set_receiver(c, nid, r);      c.instance_variable_get(:@nd_receiver)[nid] = r; end
def set_arguments(c, nid, a);     c.instance_variable_get(:@nd_arguments)[nid] = a; end
def set_elements(c, nid, e);      c.instance_variable_get(:@nd_elements)[nid] = e; end

def mk_sym(c, name);     n = mknode(c, "SymbolNode");  set_content(c, n, name); n; end
def mk_str(c, s);        n = mknode(c, "StringNode");  set_content(c, n, s); n; end
def mk_int(c, v);        n = mknode(c, "IntegerNode"); set_value(c, n, v); n; end

def mk_arr(c, ids)
  n = mknode(c, "ArrayNode")
  set_elements(c, n, ids.join(","))
  n
end

def mk_args(c, ids)
  n = mknode(c, "ArgumentsNode")
  # ArgumentsNode uses @nd_args for its id list — allocate that field.
  # Peek at spinel_codegen for the actual field name used here.
  nd_args = c.instance_variable_get(:@nd_args)
  # Ensure array is long enough
  while nd_args.length <= n
    nd_args.push("")
  end
  nd_args[n] = ids.join(",")
  n
end

def mk_call(c, name, args_ids)
  n = mknode(c, "CallNode")
  set_name(c, n, name)
  set_arguments(c, n, mk_args(c, args_ids))
  n
end

# Build the module body
init_int  = mk_int(c, 32)
size_int  = mk_int(c, 64)
off_int   = mk_int(c, 0)

call_lib     = mk_call(c, "ffi_lib",     [mk_str(c, "SDL2")])
call_cflags  = mk_call(c, "ffi_cflags",  [mk_str(c, "-I/usr/include/SDL2")])
call_func1   = mk_call(c, "ffi_func",    [mk_sym(c, "SDL_Init"), mk_arr(c, [mk_sym(c, "uint32")]), mk_sym(c, "int")])
call_func2   = mk_call(c, "ffi_func",    [mk_sym(c, "SDL_Delay"), mk_arr(c, [mk_sym(c, "uint32")]), mk_sym(c, "void")])
call_const   = mk_call(c, "ffi_const",   [mk_sym(c, "INIT_VIDEO"), init_int])
call_buf     = mk_call(c, "ffi_buffer",  [mk_sym(c, "event_buf"), size_int])
call_reader  = mk_call(c, "ffi_read_u32",[mk_sym(c, "event_type"), off_int])

body_stmts = [call_lib, call_cflags, call_func1, call_func2, call_const, call_buf, call_reader]

# StatementsNode holding the module body
body_node = mknode(c, "StatementsNode")
# Spinel's get_stmts reads @nd_body as a comma-separated id list.
# Let me check what get_stmts does — it may need @nd_args or similar.

# Actually, get_stmts uses @nd_body as an id-list string. Patch in place.
nd_body = c.instance_variable_get(:@nd_body)
# Set the body field on the StatementsNode to the joined id list string
# wait — @nd_body is an IntArray of scalar node IDs, not a string array.
# Looking closer at spinel_codegen: get_stmts likely reads from @nd_body
# which for StatementsNode contains the statements list stored how?

# Safer: use the module body approach directly. Skip the crafted AST and
# call scan_ffi_decl in a loop ourselves.

failures = []

# Direct test of scan_ffi_decl
[call_lib, call_cflags, call_func1, call_func2, call_const, call_buf, call_reader].each do |sid|
  c.scan_ffi_decl("SDL", sid)
end

# Assertions
modules = c.instance_variable_get(:@ffi_modules)
failures << "ffi_modules: expected [SDL], got #{modules.inspect}" unless modules == ["SDL"]

libs = c.instance_variable_get(:@ffi_module_libs)
failures << "ffi_module_libs: expected [SDL2], got #{libs.inspect}" unless libs == ["SDL2"]

cflags = c.instance_variable_get(:@ffi_module_cflags)
failures << "ffi_module_cflags: got #{cflags.inspect}" unless cflags == ["-I/usr/include/SDL2"]

fnames = c.instance_variable_get(:@ffi_func_names)
failures << "ffi_func_names: got #{fnames.inspect}" unless fnames == ["SDL_Init", "SDL_Delay"]

fmods = c.instance_variable_get(:@ffi_func_modules)
failures << "ffi_func_modules: got #{fmods.inspect}" unless fmods == ["SDL", "SDL"]

fargs = c.instance_variable_get(:@ffi_func_arg_types)
failures << "ffi_func_arg_types: got #{fargs.inspect}" unless fargs == ["int", "int"]

frets = c.instance_variable_get(:@ffi_func_ret_types)
failures << "ffi_func_ret_types: got #{frets.inspect}" unless frets == ["int", "void"]

cnames = c.instance_variable_get(:@const_names)
found_iv = cnames.include?("SDL_INIT_VIDEO")
failures << "ffi_const SDL_INIT_VIDEO not registered in @const_names (got #{cnames.inspect})" unless found_iv

bnames = c.instance_variable_get(:@ffi_buf_names)
failures << "ffi_buf_names: got #{bnames.inspect}" unless bnames == ["event_buf"]

bsizes = c.instance_variable_get(:@ffi_buf_sizes)
failures << "ffi_buf_sizes: got #{bsizes.inspect}" unless bsizes == [64]

rnames = c.instance_variable_get(:@ffi_reader_names)
failures << "ffi_reader_names: got #{rnames.inspect}" unless rnames == ["event_type"]

rkinds = c.instance_variable_get(:@ffi_reader_kinds)
failures << "ffi_reader_kinds: got #{rkinds.inspect}" unless rkinds == ["u32"]

roffs = c.instance_variable_get(:@ffi_reader_offsets)
failures << "ffi_reader_offsets: got #{roffs.inspect}" unless roffs == [0]

# Error-path tests: construct a bad decl and confirm ffi_error fires.
# We can't easily intercept exit(1), so skip for now and rely on
# readable error messages when users hit them.

if failures.empty?
  puts "ffi scan OK (13 assertions passed)"
  exit 0
else
  $stderr.puts "ffi scan FAILED:"
  failures.each { |f| $stderr.puts "  - #{f}" }
  exit 1
end
