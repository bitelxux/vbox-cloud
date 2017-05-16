# Shifters 2017

IMAGE := CentOS-7-x86_64-GenericCloud-1503
IMAGE_URL := https://cloud.centos.org/centos/7/images/$(IMAGE).qcow2
SIZE  := 50G
VBOX_NET := vboxnet0

RAM := 2048
ETH := enp0s3
HOST_NAME := master-xx
DOMAIN := shifters.com
IP := 10.10.10.115
NETWORK := 10.10.10.0
NETMASK := 255.255.255.0
BROADCAST := 10.10.10.255 
GATEWAY := 10.10.10.1
DNS := 8.8.8.8

help: 		## Shows this help
		@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'; \

all:		download convert cloud_init spawn

download:	$(IMAGE).qcow2.original

$(IMAGE).qcow2.original:
		wget $(IMAGE_URL)
		mv $(IMAGE).qcow2 $(IMAGE).qcow2.original

convert:	# Resizes and converts qcow2 image to virtualbox vdi
		mkdir -p images
		cp $(IMAGE).qcow2.original $(IMAGE).qcow2
		qemu-img resize $(IMAGE).qcow2 $(SIZE) 
		qemu-img convert -f qcow2 -O vdi $(IMAGE).qcow2 $(IMAGE).vdi
		mv $(IMAGE).vdi images/$(HOST_NAME).vdi

cloud_init:	# Generates the cloud-init ISO
		cp cloud-init/meta-data.template cloud-init/meta-data
		cp cloud-init/user-data.template cloud-init/user-data
		sed -i "s/<ETH>/$(ETH)/g" cloud-init/user-data
		sed -i "s/<ETH>/$(ETH)/g" cloud-init/meta-data
		sed -i "s/<HOST_NAME>/$(HOST_NAME)/g" cloud-init/meta-data
		sed -i "s/<DOMAIN>/$(DOMAIN)/g" cloud-init/meta-data
		sed -i "s/<IP>/$(IP)/g" cloud-init/meta-data
		sed -i "s/<NETWORK>/$(NETWORK)/g" cloud-init/meta-data
		sed -i "s/<NETMASK>/$(NETMASK)/g" cloud-init/meta-data
		sed -i "s/<BROADCAST>/$(BROADCAST)/g" cloud-init/meta-data
		sed -i "s/<DNS>/$(DNS)/g" cloud-init/meta-data
		sed -i "s/<GATEWAY>/$(GATEWAY)/g" cloud-init/meta-data
		genisoimage -output cloud-init/$(HOST_NAME).iso -volid cidata -joliet -rock cloud-init/user-data cloud-init/meta-data

spawn:		# Creates and launches the VM
		VBoxManage createvm --register --name $(HOST_NAME) --ostype RedHat_64
		VBoxManage modifyvm $(HOST_NAME) --memory $(RAM)
		VBoxManage storagectl $(HOST_NAME) --name "IDE Controller" --add ide
		VBoxManage modifyvm $(HOST_NAME) --hda images/$(HOST_NAME).vdi
		VBoxManage storageattach $(HOST_NAME) --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium cloud-init/$(HOST_NAME).iso
		vboxmanage modifyvm $(HOST_NAME) --nic1 hostonly
		vboxmanage modifyvm $(HOST_NAME) --nic1 hostonly --hostonlyadapter1 $(VBOX_NET)		
		vboxmanage startvm $(HOST_NAME) --type headless

stop:	 	# Stops the vm	
		vboxmanage controlvm $(HOST_NAME) poweroff

delete:		# Deletes the vm
		vboxmanage unregistervm $(HOST_NAME) --delete

clean:		# Deletes vdi and resized qcow2 image. Does not remove the qcow2.original image
		rm -f *.vdi *.qcow2 cloud-init/user-data cloud-init/meta-data
