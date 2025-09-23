rule Packer_UPX_Fingerprint {
  meta:
    author = "ETK"
    description = "UPX packed binary fingerprint"
  strings:
    $u1 = "UPX!" ascii
    $u2 = "UPX0" ascii
    $u3 = "UPX1" ascii
  condition:
    2 of ($u*)
}
