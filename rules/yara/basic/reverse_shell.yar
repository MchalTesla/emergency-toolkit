rule RS_Unix_Reverse_Shell_Snippets {
  meta:
    author = "ETK"
    description = "Common reverse/forward shell & backconnect snippets"
  strings:
    $s1 = "/dev/tcp/" ascii nocase
    $s2 = "/dev/udp/" ascii nocase
    $s3 = "bash -i" nocase
    $s4 = /(nc|ncat)\s+(-e|--sh-exec)/ nocase
    $s5 = /(socat)\s+.*(TCP|UDP)/ nocase
    $s6 = /0<&|1>&|2>&/ ascii
    $s7 = /(curl|wget)\s+[^\n]+\|(sh|bash)/ nocase
    $s8 = /python\s+-c\s+['\"]/ nocase
    $s9 = /php\s+-r\s+['\"]/ nocase
    $s10 = /mkfifo|mknod\s+[^\n]*\s+pipe/ nocase
  condition:
    2 of ($s*)
}

rule RS_PHP_Shell_Functions {
  meta:
    author = "ETK"
    description = "Dangerous PHP exec functions sequence"
  strings:
    $a1 = "shell_exec(" ascii nocase
    $a2 = "system(" ascii nocase
    $a3 = "passthru(" ascii nocase
    $a4 = "proc_open(" ascii nocase
    $a5 = "pcntl_exec(" ascii nocase
  condition:
    2 of ($a*)
}
