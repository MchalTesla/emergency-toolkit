rule ASP_ASPX_Backdoor_Traits {
  meta:
    author = "ETK"
    description = "ASP/ASPX backdoor traits and suspicious APIs"
  strings:
    $a1 = /Server\.CreateObject\s*\(/ nocase
    $a2 = /WScript\.Shell/ nocase
    $a3 = /Response\.Write\s*\(/ nocase
    $a4 = /Microsoft\.JScript\.Eval/ nocase
    $a5 = /Reflection\.Assembly\.(Load|LoadFrom)/ nocase
  condition:
    2 of ($a*)
}
