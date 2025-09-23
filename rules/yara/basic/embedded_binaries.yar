rule Embedded_ELF_or_PE_Snippets {
  meta:
    author = "ETK"
    description = "Detect embedded ELF/PE/MZ headers inside non-binaries"
  strings:
    $mz = "MZ" ascii
    $pe = "PE\x00\x00" ascii
    $elf = "\x7fELF"
  condition:
    1 of ($mz,$pe,$elf)
}
