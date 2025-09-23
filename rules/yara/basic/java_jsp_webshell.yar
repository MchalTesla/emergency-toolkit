rule JAVA_JSP_Webshell_Common {
  meta:
    author = "ETK"
    description = "Common JSP webshell traits (command execution interfaces)"
  strings:
    $j1 = "javax.servlet.http.HttpServlet" ascii
    $j2 = /ProcessBuilder\s*\(/ ascii
    $j3 = /Runtime\.getRuntime\(\)\.exec\s*\(/ ascii
    $j4 = /request\.getParameter\s*\(/ ascii
    $j5 = /Base64\.(decode|getDecoder\(\)\.decode)/ ascii
  condition:
    2 of ($j*)
}
