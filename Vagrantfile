packer_file = "alpine.pkr.hcl"
box_file = "alpine-3.23.2.box"
box_name = "alpine-local"
$script = <<-SCRIPT
packer init alpine.pkr.hcl
packer build alpine.pkr.hcl
vagrant box add --force alpine-local alpine-3.23.2.box
SCRIPT
script2 = "packer init alpine.pkr.hcl
packer build alpine.pkr.hcl
vagrant box add --force alpine-local alpine-3.23.2.box"

Vagrant.configure("2") do |config|
    config.ssh.shell = '/bin/ash'
    config.vm.box = box_name
	config.vm.provider "virtualbox" do |vb|
	  vb.memory = 2048
    end
    config.trigger.before :up do |trigger|
        rebuild = false
        if !File.exist?(box_file)
            trigger.info = "Packer box not found, building..."
            rebuild = true
        elsif File.mtime(packer_file) > File.mtime(box_file)
            trigger.info = "Packer recipe file modified, rebuilding..."
            rebuild = true
        else
            trigger.info = "Packer box is up to date"
        end
        if rebuild
            trigger.run = {
                inline:     $script
            }
        end
    end
end