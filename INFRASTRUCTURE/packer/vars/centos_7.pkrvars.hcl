# CentOS 7 Base (minimal install) — template-specific variables
# Paired with: centos-7.pkr.hcl
template_vm_id   = 2019
template_name    = "cdx-centos7-base"
iso_file         = "QNAP:iso/CentOS-7-x86_64-DVD-2009.iso"
kickstart_file   = "ks-server.cfg"
memory           = 2048
