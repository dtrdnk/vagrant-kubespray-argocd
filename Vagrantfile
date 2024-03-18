# -*- mode: ruby -*-
# vi: set ft=ruby :

# kube_node and kube_control_plane hosts with ram and cpu properties
KUBERNETES_HOSTS = [
  {hostname: "kube-control-plane-01", ram: 4096, cpu: 2},
  {hostname: "kube-control-plane-02", ram: 4096, cpu: 2},
  {hostname: "kube-control-plane-03", ram: 4096, cpu: 2},
  {hostname: "kube-node-01",          ram: 4096, cpu: 2},
  {hostname: "kube-node-02",          ram: 4096, cpu: 2},
  {hostname: "kube-node-03",          ram: 4096, cpu: 2}
]

# Keep empty. This lists for ansible inventory hosts splitting by their names
kube_node_hosts = []
control_plane_hosts = []

run_kubespray = <<-SCRIPT
docker run --name kubespray --rm  \
  -v #{ENV['PWD']}/.vagrant:#{ENV['PWD']}/.vagrant \
  -e ANSIBLE_FORCE_COLOR=true \
  -v ./inventory/group_vars:/kubespray/playbooks/group_vars \
  quay.io/kubespray/kubespray:v2.24.1 ansible-playbook \
  -i #{ENV['PWD']}/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
  --become --become-user=root cluster.yml
SCRIPT

fix_kubeconfig_permissions = <<-SCRIPT
docker run --rm \
  -v #{ENV['PWD']}/.vagrant:#{ENV['PWD']}/.vagrant \
  quay.io/kubespray/kubespray:v2.24.1 chown -R 1000:1000 \
  #{ENV['PWD']}/.vagrant/provisioners/ansible/inventory/artifacts
SCRIPT


# Libvirt plugin references:
# https://www.rubydoc.info/gems/vagrant-libvirt/0.12.2 or https://github.com/vagrant-libvirt/vagrant-libvirt
#
# Timezone plugin references:
# https://github.com/tmatilai/vagrant-timezone

REQUIRED_PLUGINS = ["vagrant-libvirt", "vagrant-timezone"]
exit unless REQUIRED_PLUGINS.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    puts "The #{plugin} plugin is required. Please install it with:"
    puts "$ vagrant plugin install #{plugin}"
    false
  )
end

Vagrant.configure(2) do |config|
  # Set timezone like in host for each VM
  config.timezone.value = :host
  KUBERNETES_HOSTS.each do |node|
    config.vm.define node[:hostname] do |config|
      config.vm.hostname = node[:hostname]
      config.vm.box = "generic-x64/ubuntu2204"
      config.vm.provider :libvirt do |domain|
        domain.memory = node[:ram]
        domain.cpus = node[:cpu]
      end

      # Filling kube_node_hosts and control_plane_hosts lists for ansible inventory generator
      if node[:hostname].start_with?("kube-node")
        kube_node_hosts << node[:hostname]
      elsif node[:hostname].start_with?("kube-control")
        control_plane_hosts << node[:hostname]
      end

      # Add workaround for execute provision only on last host
      if node.equal?(KUBERNETES_HOSTS.last)
        # Execute ansible in provision phase. Workaround for automatically generate inventory by Vagrant
        config.vm.provision :ansible do |ansible|
          ansible.verbose = "v"
          ansible.compatibility_mode = "2.0"
          ansible.playbook = "playbook.yaml"
          ansible.host_key_checking = false
          ansible.groups = {
            "kube_control_plane" => control_plane_hosts,
            "etcd" => control_plane_hosts,
            "kube_node" => kube_node_hosts,
            "k8s_cluster:children" => ["kube_control_plane", "kube_node"]
          }
        end
        # trigger will be execute, when ansible provision has done
        config.trigger.after [:provisioner_run], type: :hook do |kubespray|
          kubespray.info = "Execute kubespray in docker"
          kubespray.run = {inline: "#{run_kubespray}", keep_color: true}
          kubespray.ignore = [:destroy, :halt]
        end

        config.trigger.after [:provisioner_run], type: :hook do |fix_permissions|
          fix_permissions.info = "Run chown in docker"
          fix_permissions.run = {inline: "#{fix_kubeconfig_permissions}"}
          fix_permissions.ignore = [:destroy, :halt]
        end

        config.trigger.after [:provisioner_run], type: :hook do |fix_permissions|
          fix_permissions.info = "Run k8s_setup.sh"
          fix_permissions.run = {path: "k8s_setup.sh", args: "home-lab"}
          fix_permissions.ignore = [:destroy, :halt]
        end
      end # end provision on last node
    end # end config.vm
  end # end "each"
end
