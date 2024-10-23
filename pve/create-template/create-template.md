## Examples

```
sudo ./create-template.sh -u $VM_USER -p $VM_PSWD -k /root/.ssh/id_rsa.pub -i /mnt/pve/isos/template/iso/ubuntu-24.04.1-server-cloudimg-amd64.img --script ./customize-image.sh  --script-config ./golden-img.conf  --vmid 10000
```
