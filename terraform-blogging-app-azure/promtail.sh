#!/bin/bash
rm -f ./main/update_promtail.sh
echo "#!/bin/bash" >> ./main/update_loki.sh

L1="- url: http://`az vm show -g blogapp-rg -n loki-vm-1 --query privateIps -d --out tsv`:3100/loki/api/v1/push"
L2="- url: http://`az vm show -g blogapp-rg -n loki-vm-2 --query privateIps -d --out tsv`:3100/loki/api/v1/push"
L3="- url: http://`az vm show -g blogapp-rg -n loki-vm-3 --query privateIps -d --out tsv`:3100/loki/api/v1/push"

echo >> ./main/update_loki.sh

echo "
sed -i '/- url:/d' /opt/promtail-local-config.yaml
sed -i '/clients:/a $L1 \\n$L2 \\n$L3' /opt/promtail-local-config.yaml
" >> ./main/update_loki.sh
