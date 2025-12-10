; .com TLD Zone File - CORRECTED WITH CDX-I ROUTED IPS
; Authoritative zone for .com top-level domain
; Operator: Verisign
; Primary: com-tld-primary.cdx.lab (192.5.5.50)
; Secondary: com-tld-secondary.cdx.lab (198.41.0.50)

$TTL 172800    ; 2 days
$ORIGIN com.

@   IN  SOA com-tld-primary.cdx.lab. hostmaster.verisign.cdx.lab. (
                2024121002  ; Serial - UPDATED for IP corrections
                1800        ; Refresh
                900         ; Retry
                604800      ; Expire
                86400 )     ; Minimum TTL

; Name servers for .com TLD
@   IN  NS  com-tld-primary.cdx.lab.
@   IN  NS  com-tld-secondary.cdx.lab.

; Glue records
com-tld-primary.cdx.lab.    IN  A  192.5.5.50
com-tld-secondary.cdx.lab.  IN  A  198.41.0.50

;
; Pre-staged Top 100 Websites - .com domains
; ALL IPs use CDX-I routed space for reachability from CHILLED_ROCKET
;

; US Tech Giants (EQIX4 Seattle - 104.215.95.0/24)
google          IN  A  104.215.95.10
www.google      IN  CNAME  google
youtube         IN  A  104.215.95.11
www.youtube     IN  CNAME  youtube
facebook        IN  A  104.215.95.12
www.facebook    IN  CNAME  facebook
twitter         IN  A  104.215.95.13
www.twitter     IN  CNAME  twitter
instagram       IN  A  104.215.95.14
www.instagram   IN  CNAME  instagram
linkedin        IN  A  104.215.95.15
www.linkedin    IN  CNAME  linkedin
reddit          IN  A  104.215.95.16
www.reddit      IN  CNAME  reddit
netflix         IN  A  104.215.95.17
www.netflix     IN  CNAME  netflix
amazon          IN  A  104.215.95.18
www.amazon      IN  CNAME  amazon

; Microsoft (EQIX4 Seattle - 52.164.206.0/24 Microsoft block)
microsoft       IN  A  52.164.206.100
www.microsoft   IN  CNAME  microsoft
office          IN  A  52.164.206.101
www.office      IN  CNAME  office
live            IN  A  52.164.206.102
www.live        IN  CNAME  live
bing            IN  A  52.164.206.103
www.bing        IN  CNAME  bing
msn             IN  A  52.164.206.104
www.msn         IN  CNAME  msn
microsoft365    IN  A  52.164.206.105
www.microsoft365 IN  CNAME  microsoft365
msftconnecttest IN  A  52.164.206.56
www.msftconnecttest IN  CNAME  msftconnecttest
msftncsi        IN  A  52.164.206.217
www.msftncsi    IN  CNAME  msftncsi

; Tech & Dev (EQIX4 Seattle - 104.215.95.0/24)
github          IN  A  104.215.95.20
www.github      IN  CNAME  github
gitlab          IN  A  104.215.95.21
www.gitlab      IN  CNAME  gitlab
discord         IN  A  104.215.95.22
www.discord     IN  CNAME  discord
stackoverflow   IN  A  104.215.95.23
www.stackoverflow IN  CNAME  stackoverflow
twitch          IN  A  104.215.95.24
www.twitch      IN  CNAME  twitch
pinterest       IN  A  104.215.95.25
www.pinterest   IN  CNAME  pinterest
tumblr          IN  A  104.215.95.26
www.tumblr      IN  CNAME  tumblr

; E-commerce (EQIX4 Seattle - 104.215.95.0/24)
ebay            IN  A  104.215.95.27
www.ebay        IN  CNAME  ebay
walmart         IN  A  104.215.95.28
www.walmart     IN  CNAME  walmart
etsy            IN  A  104.215.95.29
www.etsy        IN  CNAME  etsy
shopify         IN  A  104.215.95.30
www.shopify     IN  CNAME  shopify

; Entertainment (EQIX4 Seattle - 104.215.95.0/24)
spotify         IN  A  104.215.95.31
www.spotify     IN  CNAME  spotify
soundcloud      IN  A  104.215.95.32
www.soundcloud  IN  CNAME  soundcloud
vimeo           IN  A  104.215.95.33
www.vimeo       IN  CNAME  vimeo
hulu            IN  A  104.215.95.34
www.hulu        IN  CNAME  hulu
imdb            IN  A  104.215.95.35
www.imdb        IN  CNAME  imdb

; Finance/Design/Productivity (EQIX4 Seattle - 104.215.95.0/24)
paypal          IN  A  104.215.95.36
www.paypal      IN  CNAME  paypal
apple           IN  A  104.215.95.37
www.apple       IN  CNAME  apple
adobe           IN  A  104.215.95.38
www.adobe       IN  CNAME  adobe
canva           IN  A  104.215.95.39
www.canva       IN  CNAME  canva
dropbox         IN  A  104.215.95.40
www.dropbox     IN  CNAME  dropbox
salesforce      IN  A  104.215.95.41
www.salesforce  IN  CNAME  salesforce
wordpress       IN  A  104.215.95.42
www.wordpress   IN  CNAME  wordpress
blogger         IN  A  104.215.95.43
www.blogger     IN  CNAME  blogger
medium          IN  A  104.215.95.44
www.medium      IN  CNAME  medium

; Gaming (EQIX4 Seattle - 104.215.95.0/24)
roblox          IN  A  104.215.95.45
www.roblox      IN  CNAME  roblox
steampowered    IN  A  104.215.95.46
www.steampowered IN  CNAME  steampowered

; Retail (EQIX4 Seattle - 104.215.95.0/24)
target          IN  A  104.215.95.47
www.target      IN  CNAME  target
bestbuy         IN  A  104.215.95.48
www.bestbuy     IN  CNAME  bestbuy
costco          IN  A  104.215.95.49
www.costco      IN  CNAME  costco
homedepot       IN  A  104.215.95.50
www.homedepot   IN  CNAME  homedepot
lowes           IN  A  104.215.95.51
www.lowes       IN  CNAME  lowes

; Real Estate/Services (EQIX4 Seattle - 104.215.95.0/24)
zillow          IN  A  104.215.95.52
www.zillow      IN  CNAME  zillow
realtor         IN  A  104.215.95.53
www.realtor     IN  CNAME  realtor
yelp            IN  A  104.215.95.54
www.yelp        IN  CNAME  yelp
weather         IN  A  104.215.95.55
www.weather     IN  CNAME  weather
mediafire       IN  A  104.215.95.56
www.mediafire   IN  CNAME  mediafire
instructables   IN  A  104.215.95.57
www.instructables IN  CNAME  instructables

; Travel (Mixed regions)
tripadvisor     IN  A  104.215.95.58
www.tripadvisor IN  CNAME  tripadvisor
expedia         IN  A  104.215.95.59
www.expedia     IN  CNAME  expedia
airbnb          IN  A  104.215.95.60
www.airbnb      IN  CNAME  airbnb
hotels          IN  A  104.215.95.61
www.hotels      IN  CNAME  hotels
priceline       IN  A  104.215.95.62
www.priceline   IN  CNAME  priceline
kayak           IN  A  104.215.95.63
www.kayak       IN  CNAME  kayak
booking         IN  A  37.74.100.10
www.booking     IN  CNAME  booking

; Hosting (EQIX4 Seattle - 104.215.95.0/24)
squarespace     IN  A  104.215.95.64
www.squarespace IN  CNAME  squarespace
wix             IN  A  104.215.95.65
www.wix         IN  CNAME  wix
godaddy         IN  A  104.215.95.66
www.godaddy     IN  CNAME  godaddy
namecheap       IN  A  104.215.95.67
www.namecheap   IN  CNAME  namecheap
bluehost        IN  A  104.215.95.68
www.bluehost    IN  CNAME  bluehost
hostgator       IN  A  104.215.95.69
www.hostgator   IN  CNAME  hostgator
dreamhost       IN  A  104.215.95.70
www.dreamhost   IN  CNAME  dreamhost
indeed          IN  A  104.215.95.71
www.indeed      IN  CNAME  indeed
tiktok          IN  A  104.215.95.72
www.tiktok      IN  CNAME  tiktok

; Global CDN/News (EQIX4 Seattle - 104.215.95.0/24)
cloudflare      IN  A  104.215.95.80
www.cloudflare  IN  CNAME  cloudflare
fandom          IN  A  104.215.95.81
www.fandom      IN  CNAME  fandom
cnn             IN  A  104.215.95.82
www.cnn         IN  CNAME  cnn
nytimes         IN  A  104.215.95.83
www.nytimes     IN  CNAME  nytimes
whatsapp        IN  A  104.215.95.84
www.whatsapp    IN  CNAME  whatsapp
archive         IN  A  104.215.95.85
www.archive     IN  CNAME  archive
quora           IN  A  104.215.95.86
www.quora       IN  CNAME  quora
yahoo           IN  A  104.215.95.90
www.yahoo       IN  CNAME  yahoo

; Chinese services (EQIX10 Seoul - 59.192.0.0/10)
baidu           IN  A  59.192.0.10
www.baidu       IN  CNAME  baidu
qq              IN  A  59.192.0.11
www.qq          IN  CNAME  qq
taobao          IN  A  59.192.0.12
www.taobao      IN  CNAME  taobao
tmall           IN  A  59.192.0.13
www.tmall       IN  CNAME  tmall
weibo           IN  A  59.192.0.14
www.weibo       IN  CNAME  weibo
bilibili        IN  A  59.192.0.15
www.bilibili    IN  CNAME  bilibili
sogou           IN  A  59.192.0.16
www.sogou       IN  CNAME  sogou
aliexpress      IN  A  59.192.0.17
www.aliexpress  IN  CNAME  aliexpress

; Korean services (EQIX10 Seoul - 27.160.0.0/12)
naver           IN  A  27.160.0.10
www.naver       IN  CNAME  naver
rakuten         IN  A  27.160.0.11
www.rakuten     IN  CNAME  rakuten
samsung         IN  A  27.160.0.20
www.samsung     IN  CNAME  samsung

; Russian services (EQIX7 Vladivostok - 46.3.0.0/16)
yandex          IN  A  46.3.0.10
www.yandex      IN  CNAME  yandex

; British services (EQIX1 London - 46.33.28.0/22)
bbc             IN  A  46.33.28.10
www.bbc         IN  CNAME  bbc

; Add more .com domain delegations here as needed
