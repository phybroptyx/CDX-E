; .io TLD Zone File
; Authoritative zone for .io top-level domain
; Operator: Internet Computer Bureau
; Primary: io-tld-primary.cdx.lab (192.5.5.53)
; Secondary: io-tld-secondary.cdx.lab (198.41.0.53)

$TTL 172800    ; 2 days
$ORIGIN io.

@   IN  SOA io-tld-primary.cdx.lab. hostmaster.nic.cdx.lab. (
                2024121001  ; Serial
                1800        ; Refresh
                900         ; Retry
                604800      ; Expire
                86400 )     ; Minimum TTL

; Name servers for .io TLD
@   IN  NS  io-tld-primary.cdx.lab.
@   IN  NS  io-tld-secondary.cdx.lab.

; Glue records
io-tld-primary.cdx.lab.     IN  A  192.5.5.53
io-tld-secondary.cdx.lab.   IN  A  198.41.0.53

;
; Pre-staged .io domains
;

; Documentation platforms
readthedocs     IN  NS  ns1.readthedocs.io.
readthedocs     IN  NS  ns2.readthedocs.io.

; Collaboration platforms
confluence      IN  NS  ns1.confluence.io.
confluence      IN  NS  ns2.confluence.io.

; Development platforms
github          IN  NS  ns1.github.io.
github          IN  NS  ns2.github.io.

gitlab          IN  NS  ns1.gitlab.io.
gitlab          IN  NS  ns2.gitlab.io.

; Add more .io domain delegations here as needed
