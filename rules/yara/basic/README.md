这些规则旨在在无额外模块(import)的情况下运行，兼顾通用性与比赛/攻防场景的高命中。

- 范围：反弹/正反向 shell、通用 webshell、PHP/ASP/JS 混淆关键字、恶意命令注入痕迹、可疑压缩/编码片段、内嵌 ELF/PE 片段、UPX 壳签名等。
- 兼容：避免依赖 pe/elf/dotnet/hash 等模块，适配最小功能构建的 yara。
- 命名：按类别拆分，避免过于宽泛导致误报。
- 性能：规则尽量短路匹配，避免大范围正则回溯；扫描时建议限制单文件大小，如 etk.sh 已限制 10MB。

目录：
- `reverse_shell.yar`：常见反弹/正向/回连片段
- `webshell_common.yar`：通用 webshell 关键字组合
- `php_obfuscation.yar`：PHP 混淆与危险函数调用
- `js_obfuscation.yar`：JS 混淆/编码器特征
- `suspicious_b64_zlib.yar`：过长 base64/压缩标记
- `embedded_binaries.yar`：内嵌 ELF/PE/MZ 头部片段
- `packers_basic.yar`：UPX 等基础壳标识
- `cms_wordpress.yar`：WordPress 插件/主题目录中可疑关键字与常见伪装文件名
- `cms_discuz.yar`：Discuz! 常见后门代码片段（assert/eval/preg_replace /e 等）
- `cms_thinkphp.yar`：ThinkPHP 控制器/入口结合危险函数调用特征
- `java_jsp_webshell.yar`：JSP 常见 webshell 特征（Runtime.exec/ProcessBuilder）
- `java_deserialization.yar`：Java 反序列化常见 gadget 关键词（启发式）
- `asp_aspx_backdoor.yar`：ASP/ASPX 常见后门/加载器可疑 API
