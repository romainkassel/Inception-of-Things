Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/jammy64"
    config.vm.provider "virtualbox" do |vb|
        vb.memory = 12288
        vb.cpus = 4
        vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
    end

    config.vm.synced_folder "./p1", "/p1", type: "rsync"

    config.vm.synced_folder "./p2", "/p2", type: "rsync"

    config.vm.synced_folder "./p3", "/p3", type: "rsync"

    config.vm.synced_folder "./bonus", "/bonus", type: "rsync"

    config.vm.provision "shell", inline: <<-SHELL
            apt-get update
			apt-get install vagrant -y
            apt-get install virtualbox -y
		SHELL

    config.vm.network "forwarded_port", guest: 8443, host: 8443 # ArgoCD - p3
    config.vm.network "forwarded_port", guest: 8888, host: 8888 # App - p3

end