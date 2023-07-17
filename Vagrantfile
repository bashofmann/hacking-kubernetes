Vagrant.configure("2") do |config|

  config.hostmanager.enabled = true
  config.hostmanager.manage_host = false
  config.hostmanager.manage_guest = true
  #config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline = true

  servers=[
    {
      :hostname => "rancher",
      :box => "bento/ubuntu-18.04",
      :ip => "192.168.56.100",
      :mem => 8192
    },
    {
      :hostname => "attacker",
      :box => "opensuse/Leap-15.4.x86_64",
      :ip => "192.168.56.111",
      :mem => 1024
    }

  ]

  servers.each do |machine|

    config.vm.define machine[:hostname] do |node|
      node.vm.box = machine[:box]
      node.vm.hostname = machine[:hostname]

      node.vm.network :private_network, ip: machine[:ip]
      #node.vm.network "forwarded_port", guest: 22, host: machine[:ssh_port], id: "ssh"

      node.vm.provider :virtualbox do |v|
        v.customize ["modifyvm", :id, "--memory", machine[:mem]]
        v.customize ["modifyvm", :id, "--name", machine[:hostname]]
      end

      if machine[:hostname] == 'rancher'
        node.vm.provision 'shell', path: 'provision/rancher-prep.sh'
        node.vm.provision 'shell', reboot: true
        node.vm.provision 'shell', path: 'provision/rancher.sh'
      end

      if machine[:hostname] == 'attacker'
        node.vm.provision 'shell', path: 'provision/attacker.sh'
      end

    end
  end

#  id_rsa_key_pub = File.read(File.join(Dir.home, ".ssh", "id_rsa.pub"))

#  config.vm.provision :shell,
#        :inline => "echo 'appending SSH public key to ~vagrant/.ssh/authorized_keys' && echo '#{id_rsa_key_pub }' >> /home/vagrant/.ssh/authorized_keys && chmod 600 /home/vagrant/.ssh/authorized_keys"

  config.ssh.insert_key = false

  config.vbguest.auto_update = false
end

