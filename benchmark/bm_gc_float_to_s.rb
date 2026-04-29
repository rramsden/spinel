#!/usr/bin/env ruby
# Aggressive benchmark: simulates Transformer LM workload pattern
# that triggered the >1000x GC slowdown regression in commit 4514466.
#
# The key pattern: many small matrix ops + per-element puts on floats
# = massive short-lived string allocation pressure.

# === Matrix utilities ===
def matgen(n)
  a = Array.new(n * n, 0.0)
  i = 0
  while i < n
    j = 0
    while j < n
      a[i * n + j] = (1.0 / n / n) * (i - j) * (i + j)
      j = j + 1
    end
    i = i + 1
  end
  a
end

def matmul(a, b, n)
  c = Array.new(n * n, 0.0)
  i = 0
  while i < n
    k = 0
    while k < n
      aik = a[i * n + k]
      j = 0
      while j < n
        c[i * n + j] = c[i * n + j] + aik * b[k * n + j]
        j = j + 1
      end
      k = k + 1
    end
    i = i + 1
  end
  c
end

# === Benchmark ===
n = 150
a = matgen(n)
b = matgen(n)

# Simulate Transformer LM: many forward passes with output logging
# Each pass produces n floats that get put per-line (the regression trigger)
iterations = 20
i = 0
while i < iterations
  c = matmul(a, b, n)
  # The critical part: puts on each float element (sp_float_to_s per element)
  j = 0
  while j < n
    puts c[j]
    j = j + 1
  end
  i = i + 1
end
