rule WebShell_Basics_Suspicious_PHP
{
    meta:
        description = "Basic suspicious PHP webshell traits"
        author = "EmergencyToolkit"
        reference = "generic"
        severity = "high"
    strings:
        $a1 = /eval\s*\(\s*base64_decode\s*\(/ nocase
        $a2 = /preg_replace\s*\(.+\/e/ nocase
        $a3 = /assert\s*\(/ nocase
        $a4 = /create_function\s*\(/ nocase
        $a5 = /(system|shell_exec|passthru)\s*\(/ nocase
        $a6 = /gzinflate\s*\(/ nocase
        $a7 = /fsockopen\s*\(/ nocase
        $a8 = /proc_open\s*\(/ nocase
        $a9 = /pcntl_exec\s*\(/ nocase
        $b64 = /[A-Za-z0-9+\/]{80,}={0,2}/
    condition:
        uint16(0) == 0x3c3f and (2 of ($a*) or ($a1 and $b64))
}

rule ReverseShell_Snippets_Generic
{
    meta:
        description = "Generic reverse shell snippets across shells"
        author = "EmergencyToolkit"
        reference = "generic"
        severity = "medium"
    strings:
        $s1 = "/dev/tcp" ascii nocase
        $s2 = "bash -i" ascii nocase
        $s3 = /nc\s+(-e|--sh-exec)/ nocase
        $s4 = /socat\s+.*(TCP|UDP)/ nocase
        $s5 = /curl\s+[^\n]*\|(sh|bash)/ nocase
        $s6 = /wget\s+[^\n]*\|(sh|bash)/ nocase
        $s7 = "/bin/sh -i" ascii nocase
        $s8 = /python\s+-c/ nocase
        $s9 = /php\s+-r/ nocase
    condition:
        2 of ($s*)
}
