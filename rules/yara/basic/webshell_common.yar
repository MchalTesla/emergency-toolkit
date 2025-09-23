rule WS_Generic_Webshell_Keywords {
  meta:
    author = "ETK"
    description = "Generic webshell keywords across PHP/ASP/JSP"
  strings:
    $w1 = /eval\s*\(/ nocase
    $w2 = /assert\s*\(/ nocase
    $w3 = /base64_decode\s*\(/ nocase
    $w4 = /gzinflate\s*\(/ nocase
    $w5 = /gzuncompress\s*\(/ nocase
    $w6 = /create_function\s*\(/ nocase
    $w7 = /preg_replace\s*\(.+?\/e/ nocase
    $w8 = /str_rot13\s*\(/ nocase
    $w9 = /fsockopen\s*\(/ nocase
    $w10 = /proc_open\s*\(/ nocase
    $w11 = /Response\.Write\(|eval\(/ nocase  // ASP/JSP traces
  condition:
    3 of ($w*)
}
