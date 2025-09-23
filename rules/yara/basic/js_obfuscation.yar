rule JS_Generic_Obfuscation {
  meta:
    author = "ETK"
    description = "Generic JS obfuscation patterns"
  strings:
    $j1 = /atob\s*\(/ nocase
    $j2 = /unescape\s*\(/ nocase
    $j3 = /fromCharCode\s*\(/ nocase
    $j4 = /while\s*\(\s*true\s*\)\s*\{/ nocase
    $j5 = /Function\s*\(\s*['\"]/ nocase
    $j6 = /eval\s*\(/ nocase
  condition:
    3 of ($j*)
}
