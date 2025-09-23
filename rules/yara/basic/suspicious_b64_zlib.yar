rule Suspicious_Long_Base64_Or_Zlib {
  meta:
    author = "ETK"
    description = "Suspicious long base64 blobs or zlib headers"
  strings:
    $b1 = /[A-Za-z0-9+/]{120,}={0,2}/ ascii
    $z1 = "\x78\x9c"  // zlib default compression header
    $z2 = "\x78\x01"  // no compression/low
    $z3 = "\x78\xda"  // best compression
  condition:
    $b1 or 1 of ($z*)
}
