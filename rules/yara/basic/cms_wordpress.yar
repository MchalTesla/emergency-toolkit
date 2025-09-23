rule CMS_WordPress_Malicious_Traits {
  meta:
    author = "ETK"
    description = "Suspicious WordPress plugin/theme traits (eval/base64 in wp-content)"
  strings:
    $p1 = "/wp-content/plugins/" ascii nocase
    $p2 = "/wp-content/themes/" ascii nocase
    $k1 = /eval\s*\(/ nocase
    $k2 = /base64_decode\s*\(/ nocase
    $k3 = /gzinflate\s*\(/ nocase
    $k4 = /assert\s*\(/ nocase
  condition:
    (1 of ($p*)) and (2 of ($k*))
}

rule CMS_WordPress_Backdoor_Filenames {
  meta:
    author = "ETK"
    description = "Common backdoor filenames in WordPress deployments"
  strings:
    $f1 = "wp-login.php" ascii nocase
    $f2 = "class-wp-ajax.php" ascii nocase
    $f3 = "wp-xmlrpc.php" ascii nocase
    $f4 = "wp-temp.php" ascii nocase
    $f5 = "admin-ajax.php" ascii nocase
  condition:
    1 of ($f*) and 1 of ($f1,$f5)
}
