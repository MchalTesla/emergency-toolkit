rule CMS_ThinkPHP_Backdoor_Patterns {
  meta:
    author = "ETK"
    description = "ThinkPHP suspicious controller/action injection traits"
  strings:
    $t1 = "/application/" ascii nocase
    $t2 = "/public/index.php" ascii nocase
    $k1 = /system\s*\(|shell_exec\s*\(|passthru\s*\(/ nocase
    $k2 = /call_user_func\s*\(|call_user_func_array\s*\(/ nocase
    $k3 = /preg_replace\s*\(.+?\/e/ nocase
  condition:
    (1 of ($t*)) and (2 of ($k*))
}
