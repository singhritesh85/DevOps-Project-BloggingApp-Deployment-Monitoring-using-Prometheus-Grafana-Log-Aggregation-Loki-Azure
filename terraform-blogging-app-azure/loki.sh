#!/bin/bash
rm -f ./main/update_loki.sh
echo "#!/bin/bash" >> ./main/update_loki.sh

L1=`az vm show -g blogapp-rg -n loki-vm-1 --query privateIps -d --out tsv`
L2=`az vm show -g blogapp-rg -n loki-vm-2 --query privateIps -d --out tsv`
L3=`az vm show -g blogapp-rg -n loki-vm-3 --query privateIps -d --out tsv`

echo >> ./main/update_loki.sh 

echo "cat >> /opt/loki-local-config.yaml <<EOL
memberlist:
  join_members:
    - $L1:7946
    - $L2:7946
    - $L3:7946
EOL" >> ./main/update_loki.sh
