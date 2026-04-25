# FFI smoke test: call into libm (already linked by default, no ffi_lib
# needed). Proves the FFI dispatch + extern emission + inference chain
# works without involving any external link-marker plumbing.
#
# Expected output:
#   1         (cos 0)
#   4         (sqrt 16)
#   1024      (pow 2 10)
#   12        (strlen "hello, world")

module LibM
  ffi_func :cos,  [:double], :double
  ffi_func :sqrt, [:double], :double
  ffi_func :pow,  [:double, :double], :double
end

module LibC
  ffi_func :strlen, [:str], :size_t
end

puts LibM.cos(0.0).to_i
puts LibM.sqrt(16.0).to_i
puts LibM.pow(2.0, 10.0).to_i
puts LibC.strlen("hello, world")
