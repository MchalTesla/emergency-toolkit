rule PHP_Obfuscation_Dangerous_Functions {
  meta:
    author = "ETK"
    description = "PHP obfuscation + dangerous functions"
  strings:
    $p1 = /\$\w+\s*=\s*base64_decode\(/ nocase
    $p2 = /\$\w+\s*=\s*strrev\(/ nocase
    $p3 = /\$\w+\s*=\s*gzinflate\(/ nocase
    $p4 = /\$\w+\s*=\s*gzuncompress\(/ nocase
    $p5 = /\$\w+\s*=\s*rot13\(/ nocase
    $p6 = /\$\w+\s*=\s*create_function\(/ nocase
    $d1 = /shell_exec\s*\(|system\s*\(|passthru\s*\(/ nocase
  condition:
    (2 of ($p*)) and $d1
}

rule PHP_Disable_Safe_Functions_Bypass {
  meta:
    author = "ETK"
    description = "Indicators of PHP disable_functions bypass"
  strings:
    $b1 = /putenv\s*\(/ nocase
    $b2 = /mail\s*\(/ nocase
    $b3 = /imap_open\s*\(/ nocase
    $b4 = /LD_PRELOAD|LD_LIBRARY_PATH/ nocase
  condition:
    2 of ($b*)
}
