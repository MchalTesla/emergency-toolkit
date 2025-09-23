rule JAVA_Deserialization_Gadgets_Strings {
  meta:
    author = "ETK"
    description = "Java deserialization gadget-related strings (heuristic)"
  strings:
    $g1 = "org.apache.commons.collections.functors.InvokerTransformer" ascii
    $g2 = "org.apache.commons.collections.Transformer" ascii
    $g3 = "com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl" ascii
    $g4 = "javax.management.BadAttributeValueExpException" ascii
    $g5 = "org.apache.commons.collections4.functors.InvokerTransformer" ascii
  condition:
    1 of ($g*)
}
