rule CMS_Discuz_Backdoor_Patterns {
  meta:
    author = "ETK"
    description = "Discuz! suspicious keywords and backdoor traits"
  strings:
    $d1 = "source/plugin/" ascii nocase
    $d2 = "uc_server/" ascii nocase
    $k1 = /assert\s*\(|eval\s*\(|create_function\s*\(/ nocase
    $k2 = /preg_replace\s*\(.+?\/e/ nocase
    $k3 = /base64_decode\s*\(/ nocase
  condition:
    (1 of ($d*)) and (2 of ($k*))
}
