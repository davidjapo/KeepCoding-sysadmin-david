# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
  config.vm.customize ["modifyvm", :id, "--uartmode1", "file", File::NULL]
  config.vm.network "forwarded_port", guest: 22, host: 2222, host_ip: "127.0.0.1", id: 'ssh'
  config.vm.define "wordpress" do |wordpress|
    wordpress.vm.box = "ubuntu/focal64"
    wordpress.vm.box_check_update = false
    wordpress.vm.hostname = "wordpress"
    wordpress.vm.provider "virtualbox" do |vb|
      vb.name = "ubuntu_wordpress"
      vb.memory = "1024"
      vb.cpus = "1"
      vb.default_nic_type = "virtio"
      file_to_disk = "disk_BBDD.vmdk"
      unless File.exist?(file_to_disk)
        vb.customize [ "createmedium", "disk", "--filename", "disk_BBDD.vmdk", "--format", "vmdk", "--size", 1024 * 1 ]
      end
      vb.customize [ "storageattach", "ubuntu_wordpress" , "--storagectl", "SCSI", "--port", "2", "--device", "0", "--type", "hdd", "--medium", file_to_disk]
    end
    wordpress.vm.network "private_network", ip: "192.168.10.253", nic_type: "virtio", virtualbox__intnet: "sysadmin"
    wordpress.vm.network "forwarded_port", guest: 80, host: 8080
    #wordpress.vm.provision "shell", path: "provisionWordpress.sh"
  end
    
  config.vm.define "elasticsearch" do |elasticsearch|
    elasticsearch.vm.box = "ubuntu/focal64"
    elasticsearch.vm.box_check_update = false
    elasticsearch.vm.hostname = "elasticsearch"
    elasticsearch.vm.provider "virtualbox" do |vb|
      vb.name = "ubuntu_ELK"
      vb.memory = "4096"
      vb.cpus = "1"
      vb.default_nic_type = "virtio"
      file_to_disk = "disk_elasticsearch.vmdk"
      unless File.exist?(file_to_disk)
        vb.customize [ "createmedium", "disk", "--filename", "disk_elasticsearch.vmdk", "--format", "vmdk", "--size", 1024 * 1 ]
      end
      vb.customize [ "storageattach", "ubuntu_ELK" , "--storagectl", "SCSI", "--port", "2", "--device", "0", "--type", "hdd", "--medium", file_to_disk]
    end
    elasticsearch.vm.network "private_network", ip: "192.168.10.254", nic_type: "virtio", virtualbox__intnet: "sysadmin"
    elasticsearch.vm.network "forwarded_port", guest: 80, host: 8081
    elasticsearch.vm.network "forwarded_port", guest: 9200, host: 9200
    #elasticsearch.vm.provision "shell", path: "provisionELK.sh"
  end
end
